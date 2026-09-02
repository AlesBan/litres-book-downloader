param(
    [switch]$SkipCookiesHelp
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir "config.json"

Write-Host ""
Write-Host "Litres Book Downloader - СѓСЃС‚Р°РЅРѕРІРєР°" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ConfigPath)) {
    Write-Host "РћС€РёР±РєР°: РЅРµ РЅР°Р№РґРµРЅ config.json" -ForegroundColor Red
    exit 1
}

$config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

$DownloaderDir = if ([System.IO.Path]::IsPathRooted($config.downloaderPath)) {
    $config.downloaderPath
} else {
    Join-Path $ScriptDir $config.downloaderPath
}

$DownloaderRepo = $config.downloaderRepo
$VenvDir = Join-Path $DownloaderDir ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$CookiesDir = Join-Path $ScriptDir "cookies"
$CookiesFile = Join-Path $CookiesDir "litres_cookies.json"
$BooksDir = Join-Path $ScriptDir $config.outputDir

function Find-Python {
    foreach ($cmd in @("python", "python3", "py")) {
        if ($cmd -eq "py") {
            $version = & py -3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
            if ($LASTEXITCODE -eq 0) {
                return @{ Command = "py"; Args = @("-3") }
            }
            continue
        }

        $found = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($found) {
            return @{ Command = $cmd; Args = @() }
        }
    }
    return $null
}

function Invoke-Python {
    param(
        [hashtable]$Python,
        [string[]]$ScriptArgs
    )

    if ($Python.Args.Count -gt 0) {
        & $Python.Command @($Python.Args + $ScriptArgs)
    }
    else {
        & $Python.Command @ScriptArgs
    }
}

$python = Find-Python
if (-not $python) {
    Write-Host "РћС€РёР±РєР°: Python РЅРµ РЅР°Р№РґРµРЅ." -ForegroundColor Red
    Write-Host "РЈСЃС‚Р°РЅРѕРІРёС‚Рµ Python 3.10+ СЃ https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "РџСЂРё СѓСЃС‚Р°РЅРѕРІРєРµ РѕС‚РјРµС‚СЊС‚Рµ 'Add Python to PATH'." -ForegroundColor Yellow
    exit 1
}

Write-Host "[1/5] Python РЅР°Р№РґРµРЅ" -ForegroundColor Green

if (-not (Test-Path $DownloaderDir)) {
    Write-Host "[2/5] РљР»РѕРЅРёСЂРѕРІР°РЅРёРµ Р·Р°РіСЂСѓР·С‡РёРєР°..." -ForegroundColor Yellow
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "РћС€РёР±РєР°: git РЅРµ РЅР°Р№РґРµРЅ. РЈСЃС‚Р°РЅРѕРІРёС‚Рµ Git: https://git-scm.com/download/win" -ForegroundColor Red
        exit 1
    }
    & git clone $DownloaderRepo $DownloaderDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "РћС€РёР±РєР° РїСЂРё РєР»РѕРЅРёСЂРѕРІР°РЅРёРё СЂРµРїРѕР·РёС‚РѕСЂРёСЏ." -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "[2/5] Р—Р°РіСЂСѓР·С‡РёРє СѓР¶Рµ СЃСѓС‰РµСЃС‚РІСѓРµС‚: $DownloaderDir" -ForegroundColor Green
}

if (-not (Test-Path $VenvPython)) {
    Write-Host "[3/5] РЎРѕР·РґР°РЅРёРµ РІРёСЂС‚СѓР°Р»СЊРЅРѕРіРѕ РѕРєСЂСѓР¶РµРЅРёСЏ..." -ForegroundColor Yellow
    Invoke-Python $python @("-m", "venv", $VenvDir)
    if ($LASTEXITCODE -ne 0) {
        Write-Host "РћС€РёР±РєР° РїСЂРё СЃРѕР·РґР°РЅРёРё venv." -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "[3/5] Р’РёСЂС‚СѓР°Р»СЊРЅРѕРµ РѕРєСЂСѓР¶РµРЅРёРµ СѓР¶Рµ СЃСѓС‰РµСЃС‚РІСѓРµС‚" -ForegroundColor Green
}

Write-Host "[4/5] РЈСЃС‚Р°РЅРѕРІРєР° Р·Р°РІРёСЃРёРјРѕСЃС‚РµР№..." -ForegroundColor Yellow
$requirements = Join-Path $DownloaderDir "requirements.txt"
Invoke-Python $python @("-m", "pip", "install", "--upgrade", "pip")
& $VenvPython -m pip install -r $requirements
if ($LASTEXITCODE -ne 0) {
    Write-Host "РћС€РёР±РєР° РїСЂРё СѓСЃС‚Р°РЅРѕРІРєРµ Р·Р°РІРёСЃРёРјРѕСЃС‚РµР№." -ForegroundColor Red
    exit 1
}

Write-Host "[5/5] РџРѕРґРіРѕС‚РѕРІРєР° РїР°РїРѕРє..." -ForegroundColor Yellow
foreach ($dir in @($CookiesDir, $BooksDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

if (-not (Test-Path $CookiesFile)) {
    $example = Join-Path $CookiesDir "litres_cookies.example.json"
    if (Test-Path $example) {
        Copy-Item $example $CookiesFile
    }
}

Write-Host ""
Write-Host "РЈСЃС‚Р°РЅРѕРІРєР° Р·Р°РІРµСЂС€РµРЅР°!" -ForegroundColor Green
Write-Host ""

if (-not $SkipCookiesHelp) {
    Write-Host "РЎР»РµРґСѓСЋС‰РёР№ С€Р°Рі - РЅР°СЃС‚СЂРѕРёС‚СЊ cookies РґР»СЏ Litres:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Р’Р°СЂРёР°РЅС‚ A (РёР· Р±СЂР°СѓР·РµСЂР°, СЂРµРєРѕРјРµРЅРґСѓРµС‚СЃСЏ):" -ForegroundColor White
    Write-Host "    1. Р’РѕР№РґРёС‚Рµ РЅР° litres.ru РІ Edge/Firefox/Chrome"
    Write-Host "    2. Р—Р°РїСѓСЃС‚РёС‚Рµ create_cookies.bat"
    Write-Host ""
    Write-Host "  Р’Р°СЂРёР°РЅС‚ B (Р»РѕРіРёРЅ/РїР°СЂРѕР»СЊ):" -ForegroundColor White
    Write-Host "    create_cookies.bat --login"
    Write-Host ""
    Write-Host "РџРѕСЃР»Рµ РЅР°СЃС‚СЂРѕР№РєРё cookies Р·Р°РїСѓСЃРєР°Р№С‚Рµ:" -ForegroundColor Yellow
    Write-Host "  download.bat"
    Write-Host ""
}

param(
    [switch]$Login,
    [string]$Browser = "edge"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir "config.json"
$config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

$DownloaderDir = if ([System.IO.Path]::IsPathRooted($config.downloaderPath)) {
    $config.downloaderPath
} else {
    Join-Path $ScriptDir $config.downloaderPath
}

$CookiesFile = Join-Path $ScriptDir ($config.cookiesFile -replace '/', '\')
$VenvPython = Join-Path $DownloaderDir ".venv\Scripts\python.exe"

if (-not (Test-Path $VenvPython)) {
    Write-Host "РЎРЅР°С‡Р°Р»Р° Р·Р°РїСѓСЃС‚РёС‚Рµ install.bat" -ForegroundColor Red
    exit 1
}

$cookiesDir = Split-Path $CookiesFile -Parent
if (-not (Test-Path $cookiesDir)) {
    New-Item -ItemType Directory -Path $cookiesDir -Force | Out-Null
}

Push-Location $DownloaderDir
try {
    if ($Login) {
        $email = Read-Host "Email Litres"
        $password = Read-Host "РџР°СЂРѕР»СЊ Litres" -AsSecureString
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        )
        & $VenvPython create_cookies.py -b $Browser -u $email -p $plain --cookies-file $CookiesFile
    }
    else {
        Write-Host "РР·РІР»РµС‡РµРЅРёРµ cookies РёР· Р±СЂР°СѓР·РµСЂР° ($Browser)..." -ForegroundColor Green
        Write-Host "РЈР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ РІС‹ Р°РІС‚РѕСЂРёР·РѕРІР°РЅС‹ РЅР° litres.ru РІ СЌС‚РѕРј Р±СЂР°СѓР·РµСЂРµ." -ForegroundColor Yellow
        & $VenvPython get_browser_cookies.py -b $Browser --cookies-file $CookiesFile
    }

    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    Write-Host ""
    Write-Host "Cookies СЃРѕС…СЂР°РЅРµРЅС‹: $CookiesFile" -ForegroundColor Green
}
finally {
    Pop-Location
}

param(
    [switch]$SkipDependencies
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir "config.json"

Write-Host ""
Write-Host "Litres Book Downloader - обновление" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Ошибка: git не найден. Установите Git: https://git-scm.com/download/win" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $ConfigPath)) {
    Write-Host "Ошибка: не найден config.json" -ForegroundColor Red
    exit 1
}

$config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

$DownloaderDir = if ([System.IO.Path]::IsPathRooted($config.downloaderPath)) {
    $config.downloaderPath
} else {
    Join-Path $ScriptDir ($config.downloaderPath -replace '/', '\')
}

$VenvPython = Join-Path $DownloaderDir ".venv\Scripts\python.exe"
$Requirements = Join-Path $DownloaderDir "requirements.txt"

function Update-GitRepository {
    param(
        [string]$Path,
        [string]$Title
    )

    if (-not (Test-Path $Path)) {
        Write-Host "  Пропуск: папка не найдена - $Path" -ForegroundColor Yellow
        return $true
    }

    $gitDir = Join-Path $Path ".git"
    if (-not (Test-Path $gitDir)) {
        Write-Host "  Пропуск: $Title не является git-репозиторием" -ForegroundColor Yellow
        return $true
    }

    Push-Location $Path
    try {
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Ошибка: не удалось определить ветку в $Title" -ForegroundColor Red
            return $false
        }

        $dirty = git status --porcelain
        if ($dirty) {
            Write-Host "  Внимание: есть локальные изменения в $Title" -ForegroundColor Yellow
        }

        Write-Host "  git pull ($branch)..." -ForegroundColor Gray

        $prevErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $pullOutput = (git pull --ff-only 2>&1 | Out-String).Trim()
            $pullExitCode = $LASTEXITCODE

            if ($pullExitCode -ne 0 -and $pullOutput -match 'SSL certificate problem') {
                Write-Host "  Повтор pull без проверки SSL..." -ForegroundColor Yellow
                $env:GIT_SSL_NO_VERIFY = '1'
                $pullOutput = (git pull --ff-only 2>&1 | Out-String).Trim()
                $pullExitCode = $LASTEXITCODE
            }
        }
        finally {
            $ErrorActionPreference = $prevErrorAction
        }

        if ($pullExitCode -ne 0) {
            if ($pullOutput) {
                Write-Host "  $pullOutput" -ForegroundColor DarkGray
            }
            Write-Host "  Ошибка при обновлении $Title" -ForegroundColor Red
            return $false
        }

        Write-Host "  $Title обновлен" -ForegroundColor Green
        return $true
    }
    finally {
        Pop-Location
    }
}

$step = 1
$totalSteps = if ($SkipDependencies) { 2 } else { 3 }

Write-Host "[$step/$totalSteps] Обновление litres-book-downloader..." -ForegroundColor Yellow
$wrapperOk = Update-GitRepository -Path $ScriptDir -Title "litres-book-downloader"
if (-not $wrapperOk) { exit 1 }
$step++

Write-Host ""
Write-Host "[$step/$totalSteps] Обновление загрузчика..." -ForegroundColor Yellow
if (-not (Test-Path $DownloaderDir)) {
    Write-Host "  Загрузчик не найден: $DownloaderDir" -ForegroundColor Red
    Write-Host "  Запустите install.bat для первоначальной установки" -ForegroundColor Yellow
    exit 1
}

$downloaderOk = Update-GitRepository -Path $DownloaderDir -Title "downloader"
if (-not $downloaderOk) { exit 1 }
$step++

if (-not $SkipDependencies) {
    Write-Host ""
    Write-Host "[$step/$totalSteps] Обновление Python-зависимостей..." -ForegroundColor Yellow

    if (-not (Test-Path $VenvPython)) {
        Write-Host "  venv не найден. Запустите install.bat" -ForegroundColor Red
        exit 1
    }

    if (-not (Test-Path $Requirements)) {
        Write-Host "  Не найден requirements.txt: $Requirements" -ForegroundColor Red
        exit 1
    }

    & $VenvPython -m pip install --upgrade pip
    & $VenvPython -m pip install -r $Requirements --upgrade
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Ошибка при обновлении зависимостей" -ForegroundColor Red
        exit 1
    }

    Write-Host "  Зависимости обновлены" -ForegroundColor Green
}

Write-Host ""
Write-Host "Обновление завершено!" -ForegroundColor Green
Write-Host ""

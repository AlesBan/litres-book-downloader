param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Remaining
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir "config.json"

if (-not (Test-Path $ConfigPath)) {
    Write-Host "Ошибка: не найден config.json в $ScriptDir" -ForegroundColor Red
    exit 1
}

$config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

$DownloaderDir = if ([System.IO.Path]::IsPathRooted($config.downloaderPath)) {
    $config.downloaderPath
} else {
    Join-Path $ScriptDir ($config.downloaderPath -replace '/', '\')
}
$OutputDir = Join-Path $ScriptDir $config.outputDir
$CookiesFile = Join-Path $ScriptDir ($config.cookiesFile -replace '/', '\')
$DefaultBookList = Join-Path $ScriptDir $config.defaultBookList

function Show-Usage {
    Write-Host ""
    Write-Host "Litres Book Downloader" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Использование:"
    Write-Host "  download.bat <ссылка>              - скачать одну книгу"
    Write-Host "  download.bat <путь_к_файлу.txt>    - скачать список из файла"
    Write-Host "  download.bat                       - интерактивный режим"
    Write-Host ""
    Write-Host "Примеры:"
    Write-Host "  download.bat https://www.litres.ru/book/author/nazvanie-123456/"
    Write-Host "  download.bat book_list.txt"
    Write-Host "  download.bat D:\lists\my_books.txt"
    Write-Host ""
}

function Resolve-InputPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return Join-Path $ScriptDir $Path
}

function Test-IsLitresUrl {
    param([string]$Value)
    return $Value -match 'https?://(www\.)?litres\.ru/'
}

function Invoke-Download {
    param(
        [string]$Mode,
        [string]$Target
    )

    if (-not (Test-Path $DownloaderDir)) {
        Write-Host "Ошибка: не найден загрузчик: $DownloaderDir" -ForegroundColor Red
        Write-Host "Запустите install.bat для установки" -ForegroundColor Yellow
        exit 1
    }

    if (-not (Test-Path $CookiesFile)) {
        Write-Host "Ошибка: не найден файл cookies: $CookiesFile" -ForegroundColor Red
        Write-Host "Запустите create_cookies.bat для настройки авторизации" -ForegroundColor Yellow
        exit 1
    }

    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $venvActivate = Join-Path $DownloaderDir ".venv\Scripts\Activate.ps1"
    if (-not (Test-Path $venvActivate)) {
        Write-Host "Ошибка: не найдено виртуальное окружение: $venvActivate" -ForegroundColor Red
        Write-Host "Запустите install.bat для установки" -ForegroundColor Yellow
        exit 1
    }

    Push-Location $DownloaderDir
    try {
        . $venvActivate

        $pythonArgs = @(
            "--cookies-file", $CookiesFile,
            "--output", $OutputDir,
            "-vv"
        )

        if ($Mode -eq "url") {
            Write-Host "Скачивание книги: $Target" -ForegroundColor Green
            & python download_book.py @pythonArgs --url $Target --progressbar
        }
        else {
            Write-Host "Скачивание из файла: $Target" -ForegroundColor Green
            & python multiloader.py @pythonArgs --input $Target --progressbar
        }

        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) { $exitCode = 0 }
        if ($exitCode -ne 0) {
            Write-Host "Ошибка при скачивании (код $exitCode)." -ForegroundColor Red
            exit $exitCode
        }
    }
    finally {
        if (Get-Command deactivate -ErrorAction SilentlyContinue) {
            deactivate
        }
        Pop-Location
    }

    Write-Host ""
    Write-Host "Готово. Файлы сохранены в: $OutputDir" -ForegroundColor Green
}

$userInput = $null

if ($Remaining -and $Remaining.Count -gt 0) {
    $userInput = ($Remaining -join " ").Trim()
}

if (-not $userInput) {
    Show-Usage
    Write-Host "Выберите режим:" -ForegroundColor Yellow
    Write-Host "  1 - одна ссылка"
    Write-Host "  2 - файл со списком"
    $choice = Read-Host "Ввод (1/2)"

    switch ($choice) {
        "1" {
            $userInput = Read-Host "Вставьте ссылку на книгу"
        }
        "2" {
            $fileInput = Read-Host "Путь к файлу (Enter = book_list.txt)"
            if ([string]::IsNullOrWhiteSpace($fileInput)) {
                $userInput = $DefaultBookList
            }
            else {
                $userInput = $fileInput
            }
        }
        default {
            Write-Host "Отмена." -ForegroundColor Yellow
            exit 0
        }
    }
}

$userInput = $userInput.Trim().Trim('"')

if ([string]::IsNullOrWhiteSpace($userInput)) {
    Write-Host "Ошибка: не указана ссылка или файл." -ForegroundColor Red
    exit 1
}

if (Test-IsLitresUrl $userInput) {
    Invoke-Download -Mode "url" -Target $userInput
}
else {
    $filePath = Resolve-InputPath $userInput
    if (-not (Test-Path $filePath)) {
        Write-Host "Ошибка: файл не найден: $filePath" -ForegroundColor Red
        exit 1
    }
    Invoke-Download -Mode "file" -Target $filePath
}

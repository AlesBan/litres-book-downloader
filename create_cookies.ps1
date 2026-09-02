param(
    [switch]$Login,
    [switch]$BrowserMode,
    [switch]$Manual,
    [switch]$ValidateOnly,
    [string]$Browser = "",
    [string]$Email = "",
    [string]$Password = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir "config.json"
$SetupScript = Join-Path $ScriptDir "scripts\setup_cookies.py"

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

$CookiesFile = Join-Path $ScriptDir ($config.cookiesFile -replace '/', '\')
$VenvPython = Join-Path $DownloaderDir ".venv\Scripts\python.exe"

function Invoke-SetupCookies {
    param([string[]]$PythonArgs)

    if (-not (Test-Path $VenvPython)) {
        Write-Host "Ошибка: не найдено окружение Python." -ForegroundColor Red
        Write-Host "Сначала запустите install.bat" -ForegroundColor Yellow
        exit 1
    }

    if (-not (Test-Path $SetupScript)) {
        Write-Host "Ошибка: не найден scripts\setup_cookies.py" -ForegroundColor Red
        exit 1
    }

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $VenvPython $SetupScript @PythonArgs 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $prevEap
    }

    if ($null -eq $exitCode) { $exitCode = 0 }

    foreach ($line in $output) {
        if ($line -is [System.Management.Automation.ErrorRecord]) {
            $text = $line.ToString()
        }
        else {
            $text = $line.ToString()
        }

        if ($text -match '^Error:') {
            Write-Host $text -ForegroundColor Red
        }
        elseif ($text -match '^WARNING:') {
            Write-Host $text -ForegroundColor DarkYellow
        }
        else {
            Write-Host $text
        }
    }

    return $exitCode
}

function Get-BrowserProcessNames {
    param([string]$Browser)

    switch ($Browser.ToLower()) {
        "edge" { return @("msedge") }
        "chrome" { return @("chrome") }
        "chromium" { return @("chrome", "chromium") }
        "firefox" { return @("firefox") }
        "vivaldi" { return @("vivaldi") }
        default { return @() }
    }
}

function Stop-BrowserProcesses {
    param([string]$Browser)

    $processNames = Get-BrowserProcessNames $Browser
    if ($processNames.Count -eq 0) {
        return
    }

    $running = Get-Process -Name $processNames -ErrorAction SilentlyContinue
    if (-not $running) {
        Write-Host "Фоновые процессы $Browser не найдены." -ForegroundColor Green
        return
    }

    $count = @($running).Count
    Write-Host "Найдено процессов $Browser`: $count" -ForegroundColor Yellow
    Write-Host "Edge/Chrome часто остаются в фоне даже после закрытия окон." -ForegroundColor Gray

    $answer = Read-Host "Закрыть их автоматически? (Y/n)"
    if ($answer -match '^(n|no|нет)$') {
        Write-Host "Закройте браузер через Диспетчер задач и запустите снова." -ForegroundColor Yellow
        return
    }

    foreach ($name in $processNames) {
        & taskkill /IM "$name.exe" /F 2>$null | Out-Null
    }

    Start-Sleep -Seconds 2
    Write-Host "Процессы $Browser закрыты. Ждём 2 сек..." -ForegroundColor Green
}

function Read-SecurePasswordPlain {
    $secure = Read-Host "Пароль Litres" -AsSecureString
    return [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    )
}

function Show-Help {
    Write-Host ""
    Write-Host "Litres cookies setup" -ForegroundColor Cyan
    Write-Host "====================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Использование:"
    Write-Host "  create_cookies.bat                 - интерактивный режим"
    Write-Host "  create_cookies.bat -Login          - логин и пароль (рекомендуется)"
    Write-Host "  create_cookies.bat -BrowserMode    - из браузера (браузер должен быть закрыт)"
    Write-Host "  create_cookies.bat -Manual         - ввести SID вручную"
    Write-Host "  create_cookies.bat -ValidateOnly   - проверить текущие cookies"
    Write-Host ""
}

if ($ValidateOnly) {
    exit (Invoke-SetupCookies -PythonArgs @(
        "--validate-only",
        "--cookies-file", $CookiesFile
    ))
}

$method = $null

if ($Login) { $method = "login" }
elseif ($BrowserMode) { $method = "browser" }
elseif ($Manual) { $method = "manual" }

if (-not $method) {
    Show-Help
    Write-Host "Выберите способ:" -ForegroundColor Yellow
    Write-Host "  1 - логин и пароль (рекомендуется)"
    Write-Host "  2 - из браузера (закройте браузер перед запуском)"
    Write-Host "  3 - ввести SID вручную"
    Write-Host "  4 - проверить текущие cookies"
    $choice = Read-Host "Ввод (1/2/3/4)"

    switch ($choice) {
        "1" { $method = "login" }
        "2" { $method = "browser" }
        "3" { $method = "manual" }
        "4" {
            exit (Invoke-SetupCookies -PythonArgs @(
                "--validate-only",
                "--cookies-file", $CookiesFile
            ))
        }
        default {
            Write-Host "Отмена." -ForegroundColor Yellow
            exit 0
        }
    }
}

$argsList = @(
    "--method", $method,
    "--cookies-file", $CookiesFile
)

if ($method -eq "login") {
    if (-not $Email) { $Email = Read-Host "Email или телефон Litres" }
    if (-not $Password) { $Password = Read-SecurePasswordPlain }
    $argsList += @("--email", $Email, "--password", $Password)
}
elseif ($method -eq "browser") {
    if (-not $Browser) {
        Write-Host ""
        Write-Host "Доступные браузеры: edge, chrome, firefox" -ForegroundColor Gray
        $Browser = Read-Host "Браузер (Enter = edge)"
        if ([string]::IsNullOrWhiteSpace($Browser)) { $Browser = "edge" }
    }
    Write-Host ""
    Write-Host "Сначала войдите на https://www.litres.ru в выбранном браузере." -ForegroundColor Yellow
    Write-Host "Затем полностью закройте браузер (включая фоновые процессы)." -ForegroundColor Yellow
    Read-Host "Нажмите Enter, когда окна браузера закрыты"

    Stop-BrowserProcesses -Browser $Browser

    $argsList += @("--browser", $Browser)
}
elseif ($method -eq "manual") {
    Write-Host ""
    Write-Host "Как получить SID:" -ForegroundColor Yellow
    Write-Host "  1. Откройте https://www.litres.ru и войдите в аккаунт"
    Write-Host "  2. F12 -> Application -> Cookies -> https://www.litres.ru"
    Write-Host "  3. Скопируйте значение cookie с именем SID"
    Write-Host ""
    $sid = Read-Host "Вставьте SID"
    $argsList += @("--sid", $sid)
}

$exitCode = Invoke-SetupCookies -PythonArgs $argsList
if ($exitCode -eq 0) {
    Write-Host ""
    Write-Host "Готово! Cookies настроены." -ForegroundColor Green
    Write-Host "Запускайте: download.bat" -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "Если не получилось:" -ForegroundColor Yellow
    if ($method -eq "browser") {
        Write-Host "  - Edge/Chrome: закройте все окна и фоновые процессы (Диспетчер задач -> msedge.exe)"
        Write-Host "  - или используйте способ 1: create_cookies.bat -Login"
        Write-Host "  - или способ 3: create_cookies.bat -Manual"
    }
    else {
        Write-Host "  - попробуйте способ 1 (логин и пароль)"
        Write-Host "  - или способ 3 (SID вручную из DevTools)"
        Write-Host "  - убедитесь, что install.bat уже выполнен"
    }
}

exit $exitCode

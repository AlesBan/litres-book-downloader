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
    param([string[]]$Args)

    if (-not (Test-Path $VenvPython)) {
        Write-Host "Ошибка: не найдено окружение Python." -ForegroundColor Red
        Write-Host "Сначала запустите install.bat" -ForegroundColor Yellow
        exit 1
    }

    if (-not (Test-Path $SetupScript)) {
        Write-Host "Ошибка: не найден scripts\setup_cookies.py" -ForegroundColor Red
        exit 1
    }

    & $VenvPython $SetupScript @Args
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 0 }
    return $exitCode
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
    exit (Invoke-SetupCookies @(
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
            exit (Invoke-SetupCookies @(
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
    Write-Host "Важно: полностью закройте браузер перед продолжением." -ForegroundColor Yellow
    Write-Host "Убедитесь, что вы уже вошли на litres.ru в этом браузере." -ForegroundColor Yellow
    Read-Host "Нажмите Enter, когда браузер закрыт"
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

$exitCode = Invoke-SetupCookies $argsList
if ($exitCode -ne 0) {
    Write-Host ""
    Write-Host "Если не получилось:" -ForegroundColor Yellow
    Write-Host "  - попробуйте способ 1 (логин и пароль)"
    Write-Host "  - или способ 3 (SID вручную из DevTools)"
    Write-Host "  - убедитесь, что install.bat уже выполнен"
}

exit $exitCode

# Get the script path
$scriptPath = $MyInvocation.MyCommand.Definition
$scriptDir = Split-Path -Parent $scriptPath

# Check for admin privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires administrator privileges. Attempting to elevate..." -ForegroundColor Yellow

    $escapedScriptPath = '"' + $scriptPath + '"'

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File $escapedScriptPath"
    $psi.Verb = "runas"
    $psi.WorkingDirectory = $scriptDir

    try {
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.WaitForExit()
        exit $p.ExitCode
    }
    catch {
        Write-Warning "Failed to elevate. Try running the script as administrator manually."
        Write-Warning "Error: $_"
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

# Confirm admin and policy state
Write-Host "Running with administrator privileges." -ForegroundColor Green
Write-Host "Execution Policy: $(Get-ExecutionPolicy)" -ForegroundColor Cyan

# List of apps to install via winget
$apps = @(
    @{ name = "Google Chrome"; id = "Google.Chrome" },
    @{ name = "AnyDesk"; id = "AnyDesk.AnyDesk" },
    @{ name = "WinRAR"; id = "RARLab.WinRAR" },
    @{ name = "Box Drive"; id = "Box.BoxDrive" },
    @{ name = "Adobe Acrobat Reader"; id = "Adobe.Acrobat.Reader.64-bit" }
)

foreach ($app in $apps) {
    Write-Host "Installing $($app.name)..." -ForegroundColor Cyan
    winget install --id $($app.id) --silent --accept-package-agreements --accept-source-agreements
}

# Define EXE file name and path
$exeName = "a-systmone-malaysia-live.exe"
$localInstaller = Join-Path $scriptDir $exeName

# If not found locally, attempt to download it
if (-not (Test-Path $localInstaller)) {
    Write-Warning "$exeName not found locally. Attempting to download from GitHub..."

    $exeUrl = "https://raw.githubusercontent.com/PandaMerah/cchs-setup/main/$exeName"

    try {
        Invoke-WebRequest -Uri $exeUrl -OutFile $localInstaller -ErrorAction Stop
        Write-Host "$exeName downloaded successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to download $exeName from GitHub. Check the URL: $exeUrl"
        exit 1
    }
}

# Install the EXE
Write-Host "Installing SystmOne from $localInstaller..." -ForegroundColor Cyan
Start-Process -FilePath $localInstaller -ArgumentList "/silent" -


Write-Host "All installations completed." -ForegroundColor Green
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
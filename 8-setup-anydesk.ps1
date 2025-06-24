# Set AnyDesk unattended access password by injecting directly via UI automation (2025 workaround)

# Prerequisite: AnyDesk must be installed and running at least once to initialize the config

# Requires: PowerShell + UIAutomation module (for interacting with GUI as fallback)

# Get current script path
$scriptPath = $MyInvocation.MyCommand.Definition
$scriptDir = Split-Path -Parent $scriptPath

# Elevate permissions if not running as admin
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    $psi.Verb = "runas"
    $psi.WorkingDirectory = $scriptDir
    try {
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.WaitForExit()
        exit $p.ExitCode
    } catch {
        Write-Error "Elevation failed: $_"
        exit 1
    }
}

# Try official CLI method
$anydeskPath = "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe"
if (-not (Test-Path $anydeskPath)) {
    $anydeskPath = "${env:ProgramFiles}\AnyDesk\AnyDesk.exe"
}

if (-not (Test-Path $anydeskPath)) {
    Write-Error "AnyDesk not found in standard locations."
    exit 1
}

# Try command-line password set (fails silently if GUI interaction is required)
$password = "delima90"
$cmd = "--set-password $password"
Start-Process -FilePath $anydeskPath -ArgumentList $cmd -Wait -NoNewWindow

Start-Sleep -Seconds 2

# Open Security Settings (UI fallback if CLI fails silently)
# Start-Process -FilePath $anydeskPath -ArgumentList "--set-settings", "security_unattended_access=true"
Start-Process -FilePath $anydeskPath -ArgumentList "--settings"

Write-Host "Manual interaction might be needed to finalize unattended password setup if the CLI fails silently."
Write-Host "Please verify in AnyDesk > Settings > Security."
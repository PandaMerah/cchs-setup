# Windows Setup Master Script (GitHub-based auto-fetch version)
# This script runs selected child setup scripts in order (non-interactive mode)

# ================== CONFIG START ==================
# GitHub raw base path (change to your repo!)
$repoBase = "https://raw.githubusercontent.com/PandaMerah/cchs-setup/main/"

# Define modules to run (add/remove scripts here)
$modulesToRun = @(
    "1-setup-device-name.ps1",
    "2-debloat-windows.ps1",
    "3-setup-wifi.ps1",
    "4-set-timezone.ps1",
    "5-install-apps.ps1",
    "6-uninstall-office.ps1",
    "7-setup-office.ps1",
    "8-setup-anydesk.ps1",
    "9-setup-printers.ps1",
    "10-set-wallpaper.ps1",
    "11-add-bookmarks.ps1",
    "999-output-details.ps1"
)
# ================== CONFIG END ====================

# Elevate if not admin
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires administrator privileges. Attempting to elevate..." -ForegroundColor Yellow
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$PSCommandPath`""
    $psi.Verb = "runas"
    try {
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.WaitForExit()
        exit $p.ExitCode
    } catch {
        Write-Warning "Failed to elevate. Run as Administrator manually."
        Read-Host "Press Enter to exit..."
        exit 1
    }
}

Write-Host "Running with administrator privileges." -ForegroundColor Green

# Create Restore Point
Write-Host "Creating system restore point: 'Fresh Install'..." -ForegroundColor Cyan
try {
    Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    Checkpoint-Computer -Description "Fresh Install" -RestorePointType "MODIFY_SETTINGS"
    Write-Host "Restore point created successfully." -ForegroundColor Green
} catch {
    Write-Warning "Failed to create a restore point: $_"
}

# Run scripts one by one from GitHub or local
foreach ($scriptName in $modulesToRun) {
    $localPath = Join-Path -Path $PSScriptRoot -ChildPath $scriptName
    $tempPath = Join-Path -Path $env:TEMP -ChildPath $scriptName
    $url = "$repoBase/$scriptName"

    if (Test-Path $localPath) {
        Write-Host "`nFound local copy of $scriptName. Executing..." -ForegroundColor Green
        try {
            & $localPath
        } catch {
            Write-Warning "Error executing local script $scriptName : $_"
        }
    } else {
        Write-Host "`nLocal copy of $scriptName not found. Downloading from $url..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri $url -OutFile $tempPath -UseBasicParsing
            Write-Host "Executing downloaded $scriptName..." -ForegroundColor Yellow
            & $tempPath
        } catch {
            Write-Warning "Failed to download or execute $scriptName : $_"
        }
    }
}
Write-Host "`nAll selected setup modules completed!" -ForegroundColor Green
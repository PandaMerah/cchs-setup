# Windows Setup Master Script (GitHub-based auto-fetch version)
# This script runs selected child setup scripts in order (non-interactive mode)

# ================== CONFIG START ==================
# GitHub raw base path (change to your repo!)
$repoBase = "https://raw.githubusercontent.com/PandaMerah/cchs-setup/main"

# Define modules to run (add/remove scripts here)
$modulesToRun = @(
    "1-setup-device-name.ps1",
    "2-debloat-windows.ps1",
    "3-setup-wifi.ps1",
    "4-set-timezone.ps1",
    "5-install-apps.ps1",
    # "6-uninstall-office.ps1",
    # "7-setup-office.ps1",
    # "8-setup-anydesk.ps1",
    # "9-setup-printers.ps1",
    "10-set-wallpaper.ps1"
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

# Run scripts one by one from GitHub
foreach ($scriptName in $modulesToRun) {
    $url = "$repoBase/$scriptName"
    $tempPath = Join-Path $env:TEMP $scriptName

    Write-Host "`nDownloading $scriptName..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $url -OutFile $tempPath -UseBasicParsing
        Write-Host "Executing $scriptName..." -ForegroundColor Yellow
        & $tempPath
    } catch {
        Write-Warning "Failed to download or execute $scriptName : $_"
    }
}

Write-Host "`nAll selected setup modules completed!" -ForegroundColor Green
Read-Host "Press Enter to exit..."



# # Windows Setup Master Script
# # This script runs selected child setup scripts in order (non-interactive mode)

# # Get current script path
# $scriptPath = $MyInvocation.MyCommand.Definition
# $scriptDir = Split-Path -Parent $scriptPath

# # Check for admin privileges
# if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
#     Write-Host "This script requires administrator privileges. Attempting to elevate..." -ForegroundColor Yellow
#     $escapedScriptPath = '"' + $scriptPath + '"'
#     $psi = New-Object System.Diagnostics.ProcessStartInfo
#     $psi.FileName = "powershell.exe"
#     $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File $escapedScriptPath"
#     $psi.Verb = "runas"
#     $psi.WorkingDirectory = $scriptDir
#     try {
#         $p = [System.Diagnostics.Process]::Start($psi)
#         $p.WaitForExit()
#         exit $p.ExitCode
#     } catch {
#         Write-Warning "Failed to elevate. Try running the script as administrator manually."
#         Write-Warning "Error: $_"
#         Read-Host "Press Enter to exit..."
#         exit 1
#     }
# }

# Write-Host "Running with administrator privileges." -ForegroundColor Green

# Write-Host "Creating system restore point: 'Fresh Install'..." -ForegroundColor Cyan
# try {
#     Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
#     Checkpoint-Computer -Description "Fresh Install" -RestorePointType "MODIFY_SETTINGS"
#     Write-Host "Restore point created successfully." -ForegroundColor Green
# } catch {
#     Write-Warning "Failed to create a restore point: $_"
# }

# # Define modules to run (add or remove scripts here)
# $modulesToRun = @(
#     "1-setup-device-name.ps1",
#     # "2-debloat-windows.ps1",
#     # "3-setup-wifi.ps1",
#     "4-set-timezone.ps1",
#     "5-install-apps.ps1",
#     "6-uninstall-office.ps1",
#     # "7-setup-office.ps1",
#     # "8-setup-anydesk.ps1",
#     # "9-setup-printers.ps1",
#     "10-set-wallpaper.ps1"
# )

# # Function to run each module
# function Run-Module {
#     param([string]$scriptName)
#     $fullPath = Join-Path -Path $scriptDir -ChildPath $scriptName
#     if (Test-Path $fullPath) {
#         Write-Host "Running $scriptName..." -ForegroundColor Cyan
#         try {
#             & $fullPath
#         } catch {
#             Write-Host "Error running $scriptName : $_" -ForegroundColor Red
#         }
#     } else {
#         Write-Host "Script not found: $scriptName" -ForegroundColor Red
#     }
# }

# # Execute all modules
# Write-Host "Starting setup modules..." -ForegroundColor Green
# foreach ($script in $modulesToRun) {
#     Run-Module -scriptName $script
# }

# Write-Host "\nAll selected setup modules completed!" -ForegroundColor Green
# Read-Host "Press Enter to exit..."

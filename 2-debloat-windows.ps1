# Debloat Windows
# This script performs selected cleanup tasks (widgets, taskbar tweaks, etc.)

# Ensure we're running with admin privileges
$scriptPath = $MyInvocation.MyCommand.Definition
$scriptDir = Split-Path -Parent $scriptPath

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
    } catch {
        Write-Warning "Failed to elevate. Try running the script as administrator manually."
        Write-Warning "Error: $_"
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

Write-Host "Running with administrator privileges." -ForegroundColor Green

# Disable telemetry
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0 -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0 -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0 -Force

# Disable Advertising ID
Write-Host "Disabling Advertising ID..." -ForegroundColor Yellow
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo") {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Type DWord -Value 0
}
if (Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo") {
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Type DWord -Value 0
}

# Disable background apps
# Write-Host "Disabling background apps..." -ForegroundColor Yellow
# Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" | ForEach-Object {
#     Set-ItemProperty -Path $_.PsPath -Name "Disabled" -Type DWord -Value 1
#     Set-ItemProperty -Path $_.PsPath -Name "DisabledByUser" -Type DWord -Value 1
# }

# # Disable scheduled tasks (CEIP etc.)
# Write-Host "Disabling scheduled tasks..." -ForegroundColor Yellow
# $tasks = @(
#     "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
#     "Microsoft\Windows\Application Experience\ProgramDataUpdater",
#     "Microsoft\Windows\Autochk\Proxy",
#     "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
#     "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
#     "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
# )
# foreach ($task in $tasks) {
#     $parts = $task.Split('\')
#     $name = $parts[-1]
#     $path = $parts[0..($parts.Length-2)] -join '\'
#     try {
#         Disable-ScheduledTask -TaskName "$name" -TaskPath "\$path\" -ErrorAction SilentlyContinue
#     } catch {
#         Write-Host "Failed to disable task $name: $_" -ForegroundColor Red
#     }
# }

# Remove Weather/Widgets (Windows 11 style)
Write-Host "Removing Widgets from Taskbar..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarWidgets" -Type DWord -Value 0 -Force

# Align taskbar to the left
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Type DWord -Value 0 -Force

# Hide Task View button
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Type DWord -Value 0 -Force

# Set search to icon only
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Type DWord -Value 1 -Force

# # Clear pinned taskbar items
# $TaskbarPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
# Remove-Item "$TaskbarPath\*" -Force -ErrorAction SilentlyContinue

# # Clear Start Menu pinned shortcuts
# Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\*" -Recurse -Force -ErrorAction SilentlyContinue

# # Suppress Recommended section (experimental)
# New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Force | Out-Null
# New-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "HideRecommendedSection" -Type DWord -Value 1 -Force

# Restart Explorer to apply changes
# Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Write-Host "Windows customization completed. Explorer will restart shortly." -ForegroundColor Green

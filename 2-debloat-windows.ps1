# Debloat Windows
# This script performs selected cleanup tasks and now also removes OneDrive and linked Microsoft account

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

# Remove Weather/Widgets (Windows 11 style)
Write-Host "Removing Widgets from Taskbar..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarWidgets" -Type DWord -Value 0 -Force

# Align taskbar to the left
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Type DWord -Value 0 -Force

# Hide Task View button
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Type DWord -Value 0 -Force

# Set search to icon only
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Type DWord -Value 1 -Force

# Clear Start Menu pinned shortcuts
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\*" -Recurse -Force -ErrorAction SilentlyContinue

# Suppress Recommended section (experimental)
New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Force | Out-Null
New-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "HideRecommendedSection" -Type DWord -Value 1 -Force

# === REMOVE ONEDRIVE ===
Write-Host "Uninstalling OneDrive..." -ForegroundColor Yellow
Stop-Process -Name OneDrive -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
$onedriveSetup = "$env:SystemRoot\System32\OneDriveSetup.exe"
if (Test-Path $onedriveSetup) {
    Start-Process -FilePath $onedriveSetup -ArgumentList "/uninstall" -NoNewWindow -Wait
    Write-Host "OneDrive uninstalled." -ForegroundColor Green
} else {
    Write-Warning "OneDrive setup executable not found."
}

# Remove leftover OneDrive folders
Remove-Item "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:ProgramData\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue

# === REMOVE MICROSOFT ACCOUNT LINKED TO DEVICE (if any) ===
Write-Host "Attempting to remove Microsoft account (if linked)..." -ForegroundColor Yellow
$users = Get-CimInstance -Class Win32_UserAccount | Where-Object { $_.Name -like '*@*' -and $_.LocalAccount -eq $false }
foreach ($user in $users) {
    try {
        Write-Host "Removing user: $($user.Name)" -ForegroundColor Cyan
        net user $($user.Name) /delete
    } catch {
        Write-Warning "Failed to remove user: $($user.Name). Error: $_"
    }
}

Write-Host "Debloat script completed. Some changes may require restart." -ForegroundColor Green

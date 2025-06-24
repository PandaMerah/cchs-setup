# Set Timezone and Sync with Internet Time

# Get current script path
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

# Function to set timezone
function Set-MyTimezone {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TimezoneId
    )

    try {
        # Get current timezone
        $currentTimezone = Get-TimeZone
        Write-Host "Current timezone: $($currentTimezone.DisplayName)" -ForegroundColor Yellow

        # Check if timezone is already set correctly
        if ($currentTimezone.Id -eq $TimezoneId) {
            Write-Host "Timezone is already set to $($currentTimezone.DisplayName)" -ForegroundColor Green
            return $true
        }

        # Set the timezone
        Set-TimeZone -Id $TimezoneId

        # Verify the timezone was set correctly
        $newTimezone = Get-TimeZone
        if ($newTimezone.Id -eq $TimezoneId) {
            Write-Host "Timezone successfully set to $($newTimezone.DisplayName)" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Failed to set timezone. Current timezone is still $($newTimezone.DisplayName)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "Error setting timezone: $_" -ForegroundColor Red
        return $false
    }
}

# Function to sync time with internet time servers
function Sync-InternetTime {
    try {
        # Configure Windows Time service to start automatically
        Set-Service -Name W32Time -StartupType Automatic

        # Start the Windows Time service if it's not running
        $timeService = Get-Service -Name W32Time
        if ($timeService.Status -ne "Running") {
            Start-Service -Name W32Time
        }

        # Configure NTP server
        Write-Host "Configuring NTP server..." -ForegroundColor Yellow
        w32tm /config /syncfromflags:manual /manualpeerlist:"time.windows.com time.nist.gov" /update

        # Restart the Windows Time service to apply changes
        Restart-Service -Name W32Time -Force

        # Force time sync
        Write-Host "Synchronizing time with internet time servers..." -ForegroundColor Yellow
        w32tm /resync /force

        Write-Host "Time synchronization completed." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error synchronizing time: $_" -ForegroundColor Red
        return $false
    }
}

# Main script execution
Write-Host "Timezone Setup" -ForegroundColor Cyan
Write-Host "==============" -ForegroundColor Cyan

$selectedTimezone = "Singapore Standard Time"

# Auto set timezone without prompt
Write-Host "Automatically setting timezone to: $selectedTimezone" -ForegroundColor Cyan

# Always sync time
Write-Host "Synchronizing time with internet time servers..." -ForegroundColor Cyan

Write-Host "Timezone setup completed!" -ForegroundColor Green
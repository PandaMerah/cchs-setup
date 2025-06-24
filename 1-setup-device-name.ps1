# Setup Device Name
# This script sets the Windows device name based on user input

# Check for admin privileges
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
    }
    catch {
        Write-Warning "Failed to elevate. Try running the script as administrator manually."
        Write-Warning "Error: $_"
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

Write-Host "Running with administrator privileges." -ForegroundColor Green
Write-Host "Execution Policy: $(Get-ExecutionPolicy)" -ForegroundColor Cyan

function Set-ComputerName {
    param(
        [Parameter(Mandatory=$true)]
        [string]$NewName
    )

    try {
        $currentName = $env:COMPUTERNAME

        if ($currentName -ne $NewName) {
            Write-Host "Current computer name: $currentName" -ForegroundColor Yellow
            Write-Host "Setting computer name to: $NewName" -ForegroundColor Cyan

            Rename-Computer -NewName $NewName -Force

            Write-Host "Computer name set successfully. A restart is required for changes to take effect." -ForegroundColor Green
            return $true
        } else {
            Write-Host "Computer name is already set to $NewName. No changes needed." -ForegroundColor Green
            return $false
        }
    }
    catch {
        Write-Host "Error setting computer name: $_" -ForegroundColor Red
        return $false
    }
}

# Prompt for computer name
$computerName = Read-Host "Enter the desired computer name"

if ([string]::IsNullOrWhiteSpace($computerName)) {
    $computerName = "CCHS-USER"
    Write-Host "No name provided. Using default: $computerName" -ForegroundColor Yellow
}

$requiresRestart = Set-ComputerName -NewName $computerName

if ($requiresRestart) {}

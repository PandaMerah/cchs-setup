# Konika and Sharp Printer Setup Script (Silent)
# Assumes script is run as Administrator

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

# Ensure correct working directory
Set-Location -Path $PSScriptRoot

# Function to install driver and printer
function Install-Printer {
    param (
        [string]$DriverInfPath,
        [string]$DriverName,
        [string]$PrinterName,
        [string]$PrinterIP
    )

    $portName = "IP_$($PrinterIP.Replace('.', '_'))"

    # Install driver via PrintUIEntry to ensure proper registration
    if (Test-Path $DriverInfPath) {
        Write-Host "Installing driver $DriverName from: $DriverInfPath" -ForegroundColor Cyan
        Start-Process -FilePath "rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry /ia /m `"$DriverName`" /h `"x64`" /v `"Type 3 - User Mode`" /f `"$DriverInfPath`"" -Wait -NoNewWindow
    } else {
        Write-Warning "Driver INF not found: $DriverInfPath"
        return
    }

    # Create printer port if it doesn't exist
    if (-not (Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue)) {
        Write-Host "Creating port: $portName ($PrinterIP)" -ForegroundColor Cyan
        Add-PrinterPort -Name $portName -PrinterHostAddress $PrinterIP -PortNumber 9100
    } else {
        Write-Host "Port $portName already exists." -ForegroundColor Green
    }

    # Add the printer if not already added
    if (-not (Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue)) {
        Write-Host "Adding printer: $PrinterName" -ForegroundColor Cyan
        Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $portName
    } else {
        Write-Host "Printer $PrinterName already exists." -ForegroundColor Yellow
    }
}

# === KONIKA MINOLTA ===
Install-Printer `
    -DriverInfPath ".\km-printer-driver\KOBX9J__.inf" `
    -DriverName "KONICA MINOLTA CommonDriver PCL" `
    -PrinterName "Konika Minolta Printer Lot 3 CCHS HQ" `
    -PrinterIP "192.168.1.150"

Start-Sleep -Seconds 2

# === SHARP PRINTER ===
Install-Printer `
    -DriverInfPath ".\sharp-printer-driver\ss0emenu.inf" `
    -DriverName "SHARP MX-3140N PCL6" `
    -PrinterName "Sharp Printer Lot 1 CCHS HQ" `
    -PrinterIP "192.168.1.180"

Start-Sleep -Seconds 3

Write-Host "Printers setup completed." -ForegroundColor Green
# Write-Host "Press any key to exit..."
# $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
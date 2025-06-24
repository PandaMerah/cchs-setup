# Setup PCL6 Printers
# This script adds PCL6 printers to the system

# Ensure we're running with admin privileges
# Get the script path
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

# Function to add PCL6 printer
function Add-PCL6Printer {
    param (
        [Parameter(Mandatory=$true)]
        [string]$PrinterName,
        
        [Parameter(Mandatory=$true)]
        [string]$DriverName,
        
        [Parameter(Mandatory=$true)]
        [string]$PortName,
        
        [Parameter(Mandatory=$true)]
        [string]$IPAddress
    )
    
    try {
        # Check if the printer port already exists
        $portExists = Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue
        
        if (-not $portExists) {
            # Create a new printer port
            Write-Host "Creating printer port $PortName with IP address $IPAddress..." -ForegroundColor Yellow
            Add-PrinterPort -Name $PortName -PrinterHostAddress $IPAddress -PortNumber 9100
        } else {
            Write-Host "Printer port $PortName already exists." -ForegroundColor Green
        }
        
        # Check if the printer driver is installed
        $driverInstalled = Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue
        
        if (-not $driverInstalled) {
            Write-Host "Printer driver $DriverName is not installed. Please install it first." -ForegroundColor Red
            Write-Host "You can download the driver from the printer manufacturer's website." -ForegroundColor Yellow
            return $false
        }
        
        # Check if the printer already exists
        $printerExists = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
        
        if (-not $printerExists) {
            # Add the printer
            Write-Host "Adding printer $PrinterName..." -ForegroundColor Yellow
            Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName
            Write-Host "Printer $PrinterName added successfully." -ForegroundColor Green
        } else {
            Write-Host "Printer $PrinterName already exists." -ForegroundColor Green
        }
        
        return $true
    }
    catch {
        Write-Host "Error adding printer: $_" -ForegroundColor Red
        return $false
    }
}

# Display menu for common PCL6 printer drivers
function Show-DriverMenu {
    Write-Host "Common PCL6 Printer Drivers:" -ForegroundColor Cyan
    Write-Host "[1] HP Universal Printing PCL 6"
    Write-Host "[2] Brother Universal Printer (PCL)"
    Write-Host "[3] Canon Generic Plus PCL6"
    Write-Host "[4] Lexmark Universal v2 XL"
    Write-Host "[5] Xerox Global Print Driver PCL6"
    Write-Host "[6] Kyocera PCL6 Universal"
    Write-Host "[7] Custom (enter driver name manually)"
    
    $choice = Read-Host "Select a printer driver (1-7)"
    
    switch ($choice) {
        1 { return "HP Universal Printing PCL 6" }
        2 { return "Brother Universal Printer (PCL)" }
        3 { return "Canon Generic Plus PCL6" }
        4 { return "Lexmark Universal v2 XL" }
        5 { return "Xerox Global Print Driver PCL6" }
        6 { return "Kyocera PCL6 Universal" }
        7 { return Read-Host "Enter the exact name of the installed printer driver" }
        default { return "HP Universal Printing PCL 6" }
    }
}

# Main script execution
Write-Host "PCL6 Printer Installation Script" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

# Prompt user for printer information
do {
    Write-Host "`nAdding a new printer:" -ForegroundColor Yellow
    $printerName = Read-Host "Enter printer name (e.g. 'Office-Printer-1')"
    $ipAddress = Read-Host "Enter printer IP address (e.g. '192.168.1.100')"
    
    # Generate port name from IP address if not provided
    $portName = "IP_$($ipAddress -replace '\.', '_')"
    
    # Select printer driver
    $driverName = Show-DriverMenu
    
    # Add the printer
    $result = Add-PCL6Printer -PrinterName $printerName -DriverName $driverName -PortName $portName -IPAddress $ipAddress
    
    if ($result) {
        # Set as default printer?
        $setDefault = Read-Host "Do you want to set this printer as the default printer? (Y/N)"
        if ($setDefault -eq "Y" -or $setDefault -eq "y") {
            try {
                Set-PrintConfiguration -PrinterName $printerName -Default
                Write-Host "$printerName set as default printer." -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to set as default printer: $_" -ForegroundColor Red
            }
        }
    }
    
    $addAnother = Read-Host "Do you want to add another printer? (Y/N)"
} while ($addAnother -eq "Y" -or $addAnother -eq "y")

Write-Host "Printer setup completed!" -ForegroundColor Green

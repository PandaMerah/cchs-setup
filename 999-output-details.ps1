# Asset Inventory Script for CCHS
# Created by Amri - For Internal Use Only
# Get the script path
$scriptPath = $MyInvocation.MyCommand.Definition
$scriptDir = Split-Path -Parent $scriptPath
# Check for admin privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script doesn't strictly require administrator privileges, but having them ensures it works for all users." -ForegroundColor Yellow
    Write-Host "Would you like to continue without elevation?" -ForegroundColor Cyan
    $choices = "&Yes", "&No (Elevate)"
    $decision = $Host.UI.PromptForChoice("Continue", "Continue without elevation?", $choices, 0)
   
    if ($decision -eq 1) {
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
            Write-Warning "Failed to elevate. Continuing without elevation."
            Write-Warning "Error: $_"
        }
    }
}
# Get system info
# Get the current computer name (even if pending restart)
$ComputerName = try {
    $pendingName = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" -Name ComputerName -ErrorAction SilentlyContinue).ComputerName
    if ($pendingName) { $pendingName } else { $env:COMPUTERNAME }
} catch {
    $env:COMPUTERNAME
}

$SerialNumber = (Get-CimInstance -Class Win32_BIOS).SerialNumber
$Brand = (Get-CimInstance -Class Win32_ComputerSystem).Manufacturer
$BrandModel = (Get-CimInstance -Class Win32_ComputerSystem).Model
$CPU = (Get-CimInstance -Class Win32_Processor)
$CPUName = $CPU.Name
$CPUSpeed = [math]::Round($CPU.MaxClockSpeed / 1000, 1)
$RAMCapacity = [math]::Round((Get-CimInstance -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$RAMTypeCode = (Get-CimInstance -Class Win32_PhysicalMemory | Select-Object -First 1).MemoryType
$RAMType = switch ($RAMTypeCode) {
    20 {"DDR"} 21 {"DDR2"} 24 {"DDR3"} 26 {"DDR4"} 34 {"DDR5"} default {"Unknown ($RAMTypeCode)"}
}
$RAMSticks = Get-CimInstance -Class Win32_PhysicalMemory
$RAMUsed = $RAMSticks.Count
$RAMAvailable = (Get-CimInstance -Class Win32_PhysicalMemoryArray).MemoryDevices
# Storage Info
$Disk = Get-PhysicalDisk | Where-Object MediaType -ne 'Unspecified' | Select-Object -First 1
$StorageType = $Disk.MediaType
$StorageSize = [math]::Round($Disk.Size / 1GB, 2)
# Windows Info - Fixed to properly detect Windows 11
$WinVer = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion")
$WinArch = (Get-CimInstance -Class Win32_OperatingSystem).OSArchitecture
$WinBuild = $WinVer.CurrentBuild

# Get correct version - Windows 11 uses DisplayVersion, Windows 10 uses ReleaseId
$WinRelease = if ([int]$WinBuild -ge 22000) {
    # Windows 11 uses DisplayVersion (like 22H2, 23H2, 24H2)
    if ($WinVer.DisplayVersion) { $WinVer.DisplayVersion } else { $WinVer.ReleaseId }
} else {
    # Windows 10 uses ReleaseId
    $WinVer.ReleaseId
}

# Properly detect Windows 11 vs Windows 10
$WinName = if ([int]$WinBuild -ge 22000) {
    # Windows 11 detection based on build number
    if ($WinVer.ProductName -match "Pro") {
        "Windows 11 Pro"
    } elseif ($WinVer.ProductName -match "Home") {
        "Windows 11 Home"
    } elseif ($WinVer.ProductName -match "Enterprise") {
        "Windows 11 Enterprise"
    } else {
        "Windows 11"
    }
} else {
    # Windows 10 or earlier
    $WinVer.ProductName
}

# Format info
$output = @"
LAPTOP / PC DETAIL FOR ASSET TAGGING
----------------------------------------------
[Name]              |   [Detail]
Computer Name       |   $ComputerName
Serial Number       |   $SerialNumber
Brand               |   $Brand
Laptop/PC Model     |   $BrandModel
CPU                 |   $CPUName @ ${CPUSpeed}GHz
RAM                 |   $RAMType $RAMCapacity GB
Ram Slot            |   $RAMUsed/$RAMAvailable Slot
Storage             |   $StorageSize GB - $StorageType
Windows Type        |   $WinName - Version $WinRelease - Build $WinBuild
----------------------------------------------
..::: [ This Script is created by Amri. Specially Created for CCHS internal Use only ] :::..
Press any key to to exit...
"@
# Output to screen
Write-Host $output
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
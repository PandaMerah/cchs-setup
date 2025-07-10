# Remove Microsoft Office
# This script completely removes Microsoft Office from the system

# Ensure we're running with admin privileges
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

# Function to display a confirmation prompt
function Confirm-Action {
    param (
        [string]$Title = 'Confirmation',
        [string]$Message = 'Are you sure you want to proceed?'
    )
    
    Write-Host "`n$Title" -ForegroundColor Yellow
    Write-Host "$Message" -ForegroundColor Cyan
    Write-Host "This will completely remove Microsoft Office from this computer."
    Write-Host "All Office applications, data and settings will be removed."
    
    $choices = "&Yes", "&No"
    $decision = $Host.UI.PromptForChoice($Title, "Type Y to continue or N to cancel", $choices, 1)
    
    return $decision -eq 0
}

# Function to detect installed Office versions
function Get-InstalledOfficeVersions {
    $officeVersions = @()
    
    # Check for Office installations via registry
    $officePaths = @(
        "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun\Configuration"
    )
    
    foreach ($path in $officePaths) {
        if (Test-Path $path) {
            $version = Get-ItemProperty -Path $path -Name "VersionToReport" -ErrorAction SilentlyContinue
            if ($version) {
                $officeVersions += "Click-to-Run: $($version.VersionToReport)"
            }
        }
    }
    
    # Check for MSI-based installations
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $uninstallPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -like "*Microsoft Office*" -or $_.DisplayName -like "*Microsoft 365*" } |
        ForEach-Object { $officeVersions += "MSI: $($_.DisplayName)" }
    }
    
    return $officeVersions
}

# Detect Office installations
Write-Host "`nDetecting installed Office versions..." -ForegroundColor Cyan
$installedVersions = Get-InstalledOfficeVersions

if ($installedVersions.Count -eq 0) {
    Write-Host "No Microsoft Office installations detected." -ForegroundColor Yellow
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-Host "Found the following Office installations:" -ForegroundColor Green
foreach ($version in $installedVersions) {
    Write-Host "  - $version" -ForegroundColor White
}

# Ask user for confirmation before removing Office
if (-NOT (Confirm-Action -Title "Remove Microsoft Office" -Message "This will uninstall ALL Microsoft Office applications.")) {
    Write-Host "Operation cancelled. Exiting script." -ForegroundColor Yellow
    exit
}

# Check if the Office Deployment Tool is present, if not download it
$odtPath = "$scriptDir\ODT"
$setupPath = "$odtPath\setup.exe"  # Fixed: should be setup.exe, not o-setup.exe

if (-NOT (Test-Path $setupPath)) {
    Write-Host "Office Deployment Tool not found. Downloading..." -ForegroundColor Yellow
    
    # Create ODT directory if it doesn't exist
    if (-NOT (Test-Path $odtPath)) {
        New-Item -Path $odtPath -ItemType Directory | Out-Null
    }
    
    # Updated download URL for the latest ODT
    $odtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17126-20132.exe"
    $odtInstaller = "$scriptDir\ODTSetup.exe"
    
    try {
        Write-Host "Downloading Office Deployment Tool..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $odtUrl -OutFile $odtInstaller -UseBasicParsing
        
        # Extract the Office Deployment Tool
        Write-Host "Extracting Office Deployment Tool..." -ForegroundColor Cyan
        Start-Process -FilePath $odtInstaller -ArgumentList "/quiet /extract:$odtPath" -Wait -NoNewWindow
        
        # Clean up the installer
        Remove-Item -Path $odtInstaller -Force -ErrorAction SilentlyContinue
        
        # Verify extraction
        if (-NOT (Test-Path $setupPath)) {
            throw "Setup.exe not found after extraction"
        }
        
        Write-Host "Office Deployment Tool downloaded and extracted successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to download or extract the Office Deployment Tool: $_" -ForegroundColor Red
        Write-Host "Attempting alternative uninstallation methods..." -ForegroundColor Yellow
    }
}

# Method 1: Use Office Deployment Tool (preferred method)
if (Test-Path $setupPath) {
    Write-Host "`nMethod 1: Using Office Deployment Tool..." -ForegroundColor Yellow
    
    # Create configuration XML for removal
    $configXmlPath = "$odtPath\remove_config.xml"
    $configXml = @"
<Configuration>
  <Remove All="TRUE" />
  <Display Level="Full" AcceptEULA="TRUE" />
</Configuration>
"@

    # Write the XML configuration file
    Set-Content -Path $configXmlPath -Value $configXml -Encoding UTF8
    
    Write-Host "Removing Microsoft Office using Office Deployment Tool..." -ForegroundColor Cyan
    Write-Host "This may take several minutes. Please do not close this window." -ForegroundColor Yellow
    
    try {
        $process = Start-Process -FilePath $setupPath -ArgumentList "/configure `"$configXmlPath`"" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Host "Office Deployment Tool completed successfully." -ForegroundColor Green
        } else {
            Write-Host "Office Deployment Tool completed with exit code: $($process.ExitCode)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error occurred during Office removal with ODT: $_" -ForegroundColor Red
    }
}

# Method 2: Use built-in Windows uninstaller for MSI installations
Write-Host "`nMethod 2: Attempting MSI-based uninstallation..." -ForegroundColor Yellow

$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($path in $uninstallPaths) {
    Get-ItemProperty $path -ErrorAction SilentlyContinue | 
    Where-Object { 
        ($_.DisplayName -like "*Microsoft Office*" -or $_.DisplayName -like "*Microsoft 365*") -and 
        $_.UninstallString 
    } |
    ForEach-Object {
        Write-Host "Uninstalling: $($_.DisplayName)" -ForegroundColor Cyan
        try {
            if ($_.UninstallString -like "*msiexec*") {
                # MSI uninstall
                $uninstallString = $_.UninstallString -replace "/I", "/X"
                if ($uninstallString -notlike "*/quiet*") {
                    $uninstallString += " /quiet /norestart"
                }
                Start-Process cmd -ArgumentList "/c $uninstallString" -Wait -NoNewWindow
            } else {
                # EXE uninstall
                $uninstallArgs = if ($_.QuietUninstallString) { $_.QuietUninstallString } else { $_.UninstallString + " /S" }
                Start-Process cmd -ArgumentList "/c $uninstallArgs" -Wait -NoNewWindow
            }
            Write-Host "Uninstalled: $($_.DisplayName)" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to uninstall $($_.DisplayName): $_" -ForegroundColor Red
        }
    }
}

# Method 3: Remove Office Store apps
Write-Host "`nMethod 3: Removing Office Store apps..." -ForegroundColor Yellow
try {
    $officeApps = Get-AppxPackage -AllUsers | Where-Object { 
        $_.Name -like "*Microsoft.Office*" -or 
        $_.Name -like "*Microsoft.MicrosoftOfficeHub*" -or
        $_.Name -like "*Microsoft.OutlookForWindows*" -or
        $_.Name -like "*Microsoft.MicrosoftTeams*"
    }
    
    foreach ($app in $officeApps) {
        Write-Host "Removing: $($app.Name)" -ForegroundColor Cyan
        try {
            Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            Write-Host "Removed: $($app.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to remove $($app.Name): $_" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "Error removing Store apps: $_" -ForegroundColor Red
}

# Method 4: Kill Office processes
Write-Host "`nStopping Office processes..." -ForegroundColor Yellow
$officeProcesses = @("winword", "excel", "powerpnt", "outlook", "msaccess", "mspub", "visio", "onenote", "teams", "lync", "officeclicktorun")

foreach ($process in $officeProcesses) {
    try {
        Get-Process -Name $process -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host "Stopped process: $process" -ForegroundColor Green
    }
    catch {
        # Process not running, ignore
    }
}

# Method 5: Registry cleanup
Write-Host "`nPerforming registry cleanup..." -ForegroundColor Yellow

$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Office",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office",
    "HKCU:\SOFTWARE\Microsoft\Office",
    "HKLM:\SOFTWARE\Classes\Word.Application",
    "HKLM:\SOFTWARE\Classes\Excel.Application",
    "HKLM:\SOFTWARE\Classes\PowerPoint.Application",
    "HKLM:\SOFTWARE\Classes\Outlook.Application"
)

foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        Write-Host "Removing registry keys from $path" -ForegroundColor Cyan
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Registry cleanup for $path completed." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to remove some registry keys from $path" -ForegroundColor Red
        }
    }
}

# Method 6: File system cleanup
Write-Host "`nPerforming file system cleanup..." -ForegroundColor Yellow

$officeFolders = @(
    "$env:ProgramFiles\Microsoft Office",
    "${env:ProgramFiles(x86)}\Microsoft Office",
    "$env:ProgramData\Microsoft\Office",
    "$env:LOCALAPPDATA\Microsoft\Office",
    "$env:APPDATA\Microsoft\Office",
    "$env:ProgramFiles\WindowsApps\Microsoft.Office*",
    "${env:ProgramFiles(x86)}\Microsoft\Office*"
)

foreach ($folder in $officeFolders) {
    if ($folder -like "*\*") {
        # Handle wildcards
        $basePath = Split-Path $folder -Parent
        $pattern = Split-Path $folder -Leaf
        
        if (Test-Path $basePath) {
            Get-ChildItem -Path $basePath -Directory | Where-Object { $_.Name -like $pattern } | ForEach-Object {
                Write-Host "Removing Office folder: $($_.FullName)" -ForegroundColor Cyan
                try {
                    Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "Folder cleanup for $($_.FullName) completed." -ForegroundColor Green
                }
                catch {
                    Write-Host "Failed to remove folder $($_.FullName)" -ForegroundColor Red
                }
            }
        }
    } else {
        # Handle exact paths
        if (Test-Path $folder) {
            Write-Host "Removing Office folder: $folder" -ForegroundColor Cyan
            try {
                Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "Folder cleanup for $folder completed." -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to remove folder $folder" -ForegroundColor Red
            }
        }
    }
}

# Clean up temporary files
Write-Host "`nCleaning up temporary files..." -ForegroundColor Yellow
$tempPaths = @(
    "$env:TEMP\*Office*",
    "$env:TEMP\*Microsoft*",
    "$env:LOCALAPPDATA\Temp\*Office*"
)

foreach ($tempPath in $tempPaths) {
    try {
        Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
        # Ignore temp file cleanup errors
    }
}

# Clean up ODT files
if (Test-Path $odtPath) {
    Write-Host "Cleaning up Office Deployment Tool files..." -ForegroundColor Cyan
    try {
        Remove-Item -Path $odtPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "ODT cleanup completed." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to clean up ODT files." -ForegroundColor Yellow
    }
}

# Final verification
Write-Host "`nVerifying Office removal..." -ForegroundColor Cyan
$remainingVersions = Get-InstalledOfficeVersions

if ($remainingVersions.Count -eq 0) {
    Write-Host "Microsoft Office has been successfully removed!" -ForegroundColor Green
} else {
    Write-Host "Some Office components may still remain:" -ForegroundColor Yellow
    foreach ($version in $remainingVersions) {
        Write-Host "  - $version" -ForegroundColor Red
    }
    Write-Host "You may need to manually remove these components or restart and run the script again." -ForegroundColor Yellow
}

Write-Host "`nMicrosoft Office removal process completed!" -ForegroundColor Green
Write-Host "A system restart is highly recommended to complete the cleanup process." -ForegroundColor Yellow
# Write-Host "Press any key to exit..."
# $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
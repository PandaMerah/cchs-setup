# WiFi Auto-Connect Script for CCHS

# Check for admin privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires administrator privileges. Attempting to elevate..." -ForegroundColor Yellow

    $scriptPath = $MyInvocation.MyCommand.Definition
    $escapedScriptPath = '"' + $scriptPath + '"'
    $scriptDir = Split-Path -Parent $scriptPath

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

# Function to connect to a WiFi network
function Connect-WiFiNetwork {
    param (
        [Parameter(Mandatory=$true)]
        [string]$SSID,

        [Parameter(Mandatory=$true)]
        [string]$Password,

        [Parameter(Mandatory=$false)]
        [bool]$AutoConnect = $true
    )

    try {
        # Create XML profile
        $xmlProfile = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$SSID</name>
    <SSIDConfig>
        <SSID>
            <name>$SSID</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$Password</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@

        # Save the XML profile to a temporary file
        $profilePath = "$env:TEMP\WiFiProfile.xml"
        $xmlProfile | Out-File -FilePath $profilePath -Encoding ASCII

        Write-Host "Adding WiFi profile for $SSID..." -ForegroundColor Yellow
        netsh wlan add profile filename="$profilePath" user=all

        if ($AutoConnect) {
            Write-Host "Setting auto-connect for $SSID..." -ForegroundColor Yellow
            $interfaceName = (netsh wlan show interfaces | Select-String -Pattern "Name\s+: (.+)" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() } | Select-Object -First 1)
            if ($interfaceName) {
                netsh wlan set profileparameter name="$SSID" connectionmode=auto interface="$interfaceName"
            }
        }

        Write-Host "Connecting to $SSID..." -ForegroundColor Yellow
        $connectResult = netsh wlan connect name="$SSID"

        Remove-Item -Path $profilePath -Force -ErrorAction SilentlyContinue

        if ($connectResult -match "successfully") {
            Write-Host "Successfully connected to $SSID" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Failed to connect to $SSID. Make sure the network is in range and the password is correct." -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "Error connecting to WiFi network: $_" -ForegroundColor Red
        return $false
    }
}

# Auto connect to CCHS network
$ssid = "CCHS"
$password = "125cchsHQ2023"
$autoConnect = $true

$result = Connect-WiFiNetwork -SSID $ssid -Password $password -AutoConnect $autoConnect

if ($result) {
    Write-Host "WiFi connection setup completed successfully." -ForegroundColor Green
} else {
    Write-Host "WiFi connection setup failed. Please check network availability and credentials." -ForegroundColor Red
}
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

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")


# # Setup WiFi Connection
# # This script connects to a WiFi network and saves the credentials
# # Supports unattended mode with parameters

# param(
#     [string]$SSID,
#     [string]$Password,
#     [bool]$AutoConnect = $true,
#     [switch]$Unattended
# )

# # Check if script is running as part of a larger script or standalone
# $isStandalone = $MyInvocation.ScriptName -eq $MyInvocation.InvocationName

# # Get current script path if running standalone
# if ($isStandalone) {
#     $scriptPath = $MyInvocation.MyCommand.Definition
#     $scriptDir = Split-Path -Parent $scriptPath

#     # Check for admin privileges
#     if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
#         Write-Host "This script requires administrator privileges. Attempting to elevate..." -ForegroundColor Yellow
        
#         $escapedScriptPath = '"' + $scriptPath + '"'

#         $psi = New-Object System.Diagnostics.ProcessStartInfo
#         $psi.FileName = "powershell.exe"
#         $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File $escapedScriptPath"
#         $psi.Verb = "runas"
#         $psi.WorkingDirectory = $scriptDir

#         try {
#             $p = [System.Diagnostics.Process]::Start($psi)
#             $p.WaitForExit()
#             exit $p.ExitCode
#         }
#         catch {
#             Write-Warning "Failed to elevate. Try running the script as administrator manually."
#             Write-Warning "Error: $_"
#             Write-Host "Press any key to exit..."
#             $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#             exit 1
#         }
#     }

#     # Confirm admin and policy state
#     Write-Host "Running with administrator privileges." -ForegroundColor Green
#     Write-Host "Execution Policy: $(Get-ExecutionPolicy)" -ForegroundColor Cyan
# }

# # Function to list available WiFi networks
# function Get-AvailableWiFiNetworks {
#     try {
#         $networks = netsh wlan show networks | Select-String -Pattern "SSID [0-9]+ : (.+)" | ForEach-Object {
#             $_.Matches.Groups[1].Value.Trim()
#         }
#         return $networks
#     }
#     catch {
#         Write-Host "Error listing WiFi networks: $_" -ForegroundColor Red
#         return @()
#     }
# }

# # Function to connect to a WiFi network
# function Connect-WiFiNetwork {
#     param (
#         [Parameter(Mandatory=$true)]
#         [string]$SSID,
        
#         [Parameter(Mandatory=$true)]
#         [string]$Password,
        
#         [Parameter(Mandatory=$false)]
#         [bool]$AutoConnect = $true
#     )
    
#     try {
#         # Create XML profile
#         $xmlProfile = @"
# <?xml version="1.0"?>
# <WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
#     <name>$SSID</name>
#     <SSIDConfig>
#         <SSID>
#             <name>$SSID</name>
#         </SSID>
#     </SSIDConfig>
#     <connectionType>ESS</connectionType>
#     <connectionMode>auto</connectionMode>
#     <MSM>
#         <security>
#             <authEncryption>
#                 <authentication>WPA2PSK</authentication>
#                 <encryption>AES</encryption>
#                 <useOneX>false</useOneX>
#             </authEncryption>
#             <sharedKey>
#                 <keyType>passPhrase</keyType>
#                 <protected>false</protected>
#                 <keyMaterial>$Password</keyMaterial>
#             </sharedKey>
#         </security>
#     </MSM>
# </WLANProfile>
# "@
        
#         # Save the XML profile to a temporary file
#         $profilePath = "$env:TEMP\WiFiProfile.xml"
#         $xmlProfile | Out-File -FilePath $profilePath -Encoding ASCII
        
#         # Add the WiFi profile
#         Write-Host "Adding WiFi profile for $SSID..." -ForegroundColor Yellow
#         $output = netsh wlan add profile filename="$profilePath" user=all
        
#         # Set auto-connection preference if specified
#         if ($AutoConnect) {
#             Write-Host "Setting auto-connect for $SSID..." -ForegroundColor Yellow
#             $interfaceName = (netsh wlan show interfaces | Select-String -Pattern "Name\s+: (.+)" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() } | Select-Object -First 1)
#             if ($interfaceName) {
#                 netsh wlan set profileparameter name="$SSID" connectionmode=auto interface="$interfaceName"
#             }
#         }
        
#         # Connect to the network
#         Write-Host "Connecting to $SSID..." -ForegroundColor Yellow
#         $connectResult = netsh wlan connect name="$SSID"
        
#         # Delete the temporary profile file
#         Remove-Item -Path $profilePath -Force -ErrorAction SilentlyContinue
        
#         if ($connectResult -match "successfully") {
#             Write-Host "Successfully connected to $SSID" -ForegroundColor Green
#             return $true
#         } else {
#             Write-Host "Failed to connect to $SSID. Make sure the network is in range and the password is correct." -ForegroundColor Red
#             return $false
#         }
#     }
#     catch {
#         Write-Host "Error connecting to WiFi network: $_" -ForegroundColor Red
#         return $false
#     }
# }

# # Main script execution
# Write-Host "WiFi Connection Setup" -ForegroundColor Cyan
# Write-Host "====================" -ForegroundColor Cyan

# # Check if WiFi adapter is available
# $wifiAdapters = Get-NetAdapter |
#     Where-Object {
#       ($_.InterfaceDescription -match 'Wireless|Wi-?Fi') -and
#       ($_.Status -eq 'Up')
#     }
# if (-not $wifiAdapters) {
#     Write-Host "No active WiFi adapter found. Please make sure WiFi is enabled on your device." -ForegroundColor Red
#     exit
# }

# # Unattended or interactive mode determination
# if ($Unattended -and $SSID -and $Password) {
#     # Unattended mode with provided credentials
#     Write-Host "Running in unattended mode with provided WiFi credentials" -ForegroundColor Cyan
    
#     # Connect to WiFi
#     $result = Connect-WiFiNetwork -SSID $SSID -Password $Password -AutoConnect $AutoConnect
    
#     if ($result) {
#         Write-Host "WiFi connection setup completed successfully." -ForegroundColor Green
#     } else {
#         Write-Host "WiFi connection setup failed in unattended mode." -ForegroundColor Red
#         # Don't exit with error in unattended mode, let the script continue
#     }
# }
# else {
#     # Interactive mode
    
#     # Get available WiFi networks
#     Write-Host "Scanning for available WiFi networks..." -ForegroundColor Yellow
#     $availableNetworks = Get-AvailableWiFiNetworks

#     if ($availableNetworks.Count -eq 0) {
#         Write-Host "No WiFi networks found. Please make sure your WiFi adapter is working properly." -ForegroundColor Red
#         exit
#     }

#     # Display available networks
#     Write-Host "Available WiFi Networks:" -ForegroundColor Green
#     for ($i = 0; $i -lt $availableNetworks.Count; $i++) {
#         Write-Host "[$i] $($availableNetworks[$i])"
#     }
#     Write-Host "[M] Manually enter network name"

#     # Get user selection
#     $selection = Read-Host "Select a network to connect to (enter number or M)"

#     if ($selection -eq "M" -or $selection -eq "m") {
#         $ssid = Read-Host "Enter the WiFi network name (SSID)"
#     } else {
#         try {
#             $index = [int]$selection
#             if ($index -ge 0 -and $index -lt $availableNetworks.Count) {
#                 $ssid = $availableNetworks[$index]
#             } else {
#                 Write-Host "Invalid selection. Please manually enter the network name." -ForegroundColor Red
#                 $ssid = Read-Host "Enter the WiFi network name (SSID)"
#             }
#         }
#         catch {
#             Write-Host "Invalid selection. Please manually enter the network name." -ForegroundColor Red
#             $ssid = Read-Host "Enter the WiFi network name (SSID)"
#         }
#     }

#     # Get password
#     $securePassword = Read-Host "Enter the WiFi password" -AsSecureString
#     $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
#     $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
#     [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

#     # Auto-connect?
#     $response = Read-Host "Automatically connect to this network when in range? (Y/N)"
#     $autoConnectBool = ($response -eq "Y" -or $response -eq "y")

#     # Connect to WiFi
#     $result = Connect-WiFiNetwork -SSID $ssid -Password $password -AutoConnect $autoConnectBool

#     if ($result) {
#         Write-Host "WiFi connection setup completed successfully." -ForegroundColor Green
#     } else {
#         Write-Host "WiFi connection setup failed. Please try again manually." -ForegroundColor Red
#     }
# }
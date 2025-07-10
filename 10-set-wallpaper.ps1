# Set Windows Wallpaper
# This script sets the Windows wallpaper from an image in the current directory

# Get the script path
$scriptPath = $MyInvocation.MyCommand.Definition
$scriptDir = Split-Path -Parent $scriptPath

# Check for admin privileges (not strictly necessary for wallpaper, but included for consistency)
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

# Define wallpaper file path
$wallpaperFileName = "W-CCHS-WALLPAPER.jpg"
$wallpaperPath = Join-Path -Path $scriptDir -ChildPath $wallpaperFileName

# If wallpaper is missing, attempt to download from GitHub
if (-not (Test-Path $wallpaperPath)) {
    Write-Warning "Wallpaper not found locally. Attempting to download from GitHub..."

    $wallpaperUrl = "https://raw.githubusercontent.com/PandaMerah/cchs-setup/main/W-CCHS-WALLPAPER.jpg"

    try {
        Invoke-WebRequest -Uri $wallpaperUrl -OutFile $wallpaperPath -ErrorAction Stop
        Write-Host "Wallpaper downloaded successfully to: $wallpaperPath" -ForegroundColor Green
    } catch {
        Write-Error "Failed to download wallpaper from GitHub. Ensure the file exists at: $wallpaperUrl"
        exit 1
    }
}


Write-Host "Found wallpaper: $wallpaperPath" -ForegroundColor Green

# Add Windows API types for wallpaper setting
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    
    public const int SPI_SETDESKWALLPAPER = 0x0014;
    public const int SPIF_UPDATEINIFILE = 0x01;
    public const int SPIF_SENDCHANGE = 0x02;
}
"@

# Function to set wallpaper for current user
function Set-WallpaperCurrentUser {
    param([string]$Path)
    
    try {
        # Set wallpaper using Windows API
        $result = [Wallpaper]::SystemParametersInfo(20, 0, $Path, 3)
        
        if ($result -eq 0) {
            throw "SystemParametersInfo failed"
        }
        
        # Set wallpaper style to Fill (6) in registry
        $regPath = "HKCU:\Control Panel\Desktop"
        Set-ItemProperty -Path $regPath -Name "WallpaperStyle" -Value "6" -Force
        Set-ItemProperty -Path $regPath -Name "TileWallpaper" -Value "0" -Force
        
        Write-Host "Wallpaper set successfully for current user" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "Failed to set wallpaper for current user: $_"
        return $false
    }
}

# Function to set default wallpaper for all users (requires admin)
function Set-DefaultWallpaperAllUsers {
    param([string]$Path)
    
    try {
        # Copy wallpaper to Windows directory for system-wide access
        $systemWallpaperPath = Join-Path $env:WINDIR "Web\Wallpaper\Windows\W-CCHS-WALLPAPER.jpg"
        Copy-Item -Path $Path -Destination $systemWallpaperPath -Force
        
        # Set default wallpaper in registry for new users
        $defaultUserRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        
        # Create the registry key if it doesn't exist
        if (-not (Test-Path $defaultUserRegPath)) {
            New-Item -Path $defaultUserRegPath -Force | Out-Null
        }
        
        # Set the wallpaper path for all users
        Set-ItemProperty -Path $defaultUserRegPath -Name "Wallpaper" -Value $systemWallpaperPath -Force
        Set-ItemProperty -Path $defaultUserRegPath -Name "WallpaperStyle" -Value "6" -Force
        
        # Also set in default user profile
        $defaultUserHive = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\S-1-5-21-Default\Control Panel\Desktop"
        
        # Load default user registry hive
        reg load "HKU\DefaultUser" "$env:SystemDrive\Users\Default\NTUSER.DAT" 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            $defaultDesktopPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\.Default\Control Panel\Desktop"
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\.Default\Control Panel\Desktop" -Name "Wallpaper" -Value $systemWallpaperPath -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\.Default\Control Panel\Desktop" -Name "WallpaperStyle" -Value "6" -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\.Default\Control Panel\Desktop" -Name "TileWallpaper" -Value "0" -Force -ErrorAction SilentlyContinue
            
            # Unload the hive
            reg unload "HKU\DefaultUser" 2>$null
        }
        
        Write-Host "Default wallpaper set for all users" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "Failed to set default wallpaper for all users: $_"
        return $false
    }
}

# Main execution
Write-Host "Setting wallpaper..." -ForegroundColor Cyan

# Always set for current user
$currentUserSuccess = Set-WallpaperCurrentUser -Path $wallpaperPath

# If running as admin, also set for all users
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if ($isAdmin) {
    Write-Host "Running as administrator - setting default wallpaper for all users..." -ForegroundColor Cyan
    $allUsersSuccess = Set-DefaultWallpaperAllUsers -Path $wallpaperPath
    
    if ($currentUserSuccess -and $allUsersSuccess) {
        Write-Host "Wallpaper successfully set for current user and as default for all users!" -ForegroundColor Green
    } elseif ($currentUserSuccess) {
        Write-Host "Wallpaper set for current user, but failed to set default for all users." -ForegroundColor Yellow
    } else {
        Write-Host "Failed to set wallpaper." -ForegroundColor Red
        exit 1
    }
} else {
    if ($currentUserSuccess) {
        Write-Host "Wallpaper successfully set for current user!" -ForegroundColor Green
        Write-Host "Note: Run as administrator to set default wallpaper for all users." -ForegroundColor Yellow
    } else {
        Write-Host "Failed to set wallpaper." -ForegroundColor Red
        exit 1
    }
}

# Refresh desktop
try {
    # Force desktop refresh
    $code = @"
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetSysColors(int cElements, int[] lpaElements, int[] lpaRgbValues);
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool InvalidateRect(IntPtr hWnd, IntPtr lpRect, bool bErase);
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern IntPtr GetDesktopWindow();
"@
    
    Add-Type -MemberDefinition $code -Name "Win32" -Namespace "User32"
    
    $desktop = [User32.Win32]::GetDesktopWindow()
    [User32.Win32]::InvalidateRect($desktop, [IntPtr]::Zero, $true)
    
    Write-Host "Desktop refreshed." -ForegroundColor Green
}
catch {
    Write-Host "Desktop refresh may be required manually." -ForegroundColor Yellow
}

Write-Host "Set wallpaper completed successfully!" -ForegroundColor Green
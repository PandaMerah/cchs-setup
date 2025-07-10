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
        # $p.WaitForExit()
        # exit $p.ExitCode
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

$bat = Join-Path $PSScriptRoot 'o-setup.bat'

Write-Host "Starting installer with elevation (if needed)..." -ForegroundColor Cyan
Start-Process `
    -FilePath $bat `
    -WorkingDirectory $PSScriptRoot `
    -Verb RunAs `
    -Wait

# After -Wait returns, you can inspect the exit code:
$proc = Get-Process | Where-Object { $_.Path -eq (Resolve-Path $bat).Path } 
# (or simply rely on $LASTEXITCODE if your PS is the parent)
Write-Host "Installer process ended." -ForegroundColor Green
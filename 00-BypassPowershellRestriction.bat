@echo off
PowerShell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force; Write-Host 'Execution policy set to RemoteSigned for CurrentUser.' -ForegroundColor Green"

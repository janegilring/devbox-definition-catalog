@echo off
echo Git SSH Signing Setup with Entra ID Auto-Detection
echo ==================================================
echo.
echo This script will:
echo 1. Auto-detect your Entra ID email and username
echo 2. Configure Git user settings
echo 3. Generate a new SSH signing key
echo 4. Configure Git for SSH commit signing
echo.
pause

powershell -ExecutionPolicy Bypass -Command "& { . '%~dp0git-entra-auto-config.ps1'; New-GitSigningKeyWithAutoConfig }"

echo.
echo Setup complete! Press any key to exit...
pause >nul
@echo off
echo Starting Git SSH Signing Setup...
powershell -ExecutionPolicy Bypass -File "%~dp0setup-git-signing.ps1" %*
pause
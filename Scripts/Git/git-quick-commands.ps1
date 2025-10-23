# One-liner commands for Git SSH signing setup with Entra ID auto-detection

# Quick setup (run this in PowerShell):
# iex (Get-Content git-entra-auto-config.ps1 -Raw); New-GitSigningKeyWithAutoConfig

# Or load the function and run:
# . .\git-entra-auto-config.ps1; gitkey-auto

# Add to PowerShell profile for permanent access:
# Add-Content $PROFILE -Value (Get-Content git-entra-auto-config.ps1 -Raw)

Write-Host "Git SSH Signing Quick Commands:" -ForegroundColor Green
Write-Host ""
Write-Host "1. Quick one-time setup:" -ForegroundColor Yellow
Write-Host "   iex (Get-Content git-entra-auto-config.ps1 -Raw); New-GitSigningKeyWithAutoConfig" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Load function and run:" -ForegroundColor Yellow
Write-Host "   . .\git-entra-auto-config.ps1; gitkey-auto" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Add to PowerShell profile (permanent):" -ForegroundColor Yellow
Write-Host "   Add-Content `$PROFILE -Value (Get-Content git-entra-auto-config.ps1 -Raw)" -ForegroundColor Cyan
Write-Host "   Then restart PowerShell and run: gitkey-auto" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Use the batch file:" -ForegroundColor Yellow
Write-Host "   setup-git-entra-auto.bat" -ForegroundColor Cyan
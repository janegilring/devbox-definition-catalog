# Quick Git SSH Signing Key Generator
# Simple script to create a new SSH key and configure Git signing

param(
    [string]$KeyComment = ""
)

Write-Host "🔑 Quick Git SSH Signing Setup" -ForegroundColor Green
Write-Host ""

# Get current Git user info
$gitName = git config --global user.name 2>$null
$gitEmail = git config --global user.email 2>$null

if (-not $gitEmail) {
    Write-Error "Git email not configured. Run: git config --global user.email 'your@email.com'"
    exit 1
}

# Set default comment
if (-not $KeyComment) {
    $KeyComment = "$gitEmail - Git Signing $(Get-Date -Format 'yyyy-MM-dd')"
}

get-service ssh-agent | Set-Service -StartupType Automatic
get-service ssh-agent | Start-Service

# Generate timestamp for unique key name
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$keyName = "git_signing_$timestamp"
$sshDir = "$env:USERPROFILE\.ssh"
$privateKey = "$sshDir\$keyName"
$publicKey = "$sshDir\$keyName.pub"

# Ensure SSH directory exists
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

Write-Host "📁 SSH Directory: $sshDir" -ForegroundColor Cyan
Write-Host "🔐 Generating key: $keyName" -ForegroundColor Cyan

# Generate SSH key
ssh-keygen -t ed25519 -f $privateKey -C $KeyComment -N ""

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to generate SSH key"
    exit 1
}

Write-Host "✅ SSH key generated successfully!" -ForegroundColor Green

# Add to SSH agent
Write-Host "🔄 Adding key to SSH agent..." -ForegroundColor Cyan
ssh-add $privateKey

# Configure Git
Write-Host "⚙️ Configuring Git..." -ForegroundColor Cyan
git config --global user.signingkey $publicKey
git config --global gpg.format ssh
git config --global commit.gpgsign true

Write-Host ""
Write-Host "🎉 Setup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Signing Key: $publicKey" -ForegroundColor Gray
Write-Host "  Format: SSH" -ForegroundColor Gray
Write-Host "  Auto-sign commits: Enabled" -ForegroundColor Gray
Write-Host ""
Write-Host "📋 Your public key (add to GitHub/GitLab):" -ForegroundColor Yellow
Get-Content $publicKey
Write-Host ""
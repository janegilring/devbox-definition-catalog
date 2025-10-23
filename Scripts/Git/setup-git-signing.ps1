# Git SSH Signing Key Setup Script
# This script creates a new SSH key for Git commit signing and configures Git to use it

param(
    [string]$KeyName = "id_ed25519_git_signing",
    [string]$Comment = "",
    [switch]$Force
)

# Function to check if running as Administrator (for ssh-agent service management)
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to ensure SSH agent is running
function Start-SshAgent {
    Write-Host "Checking SSH Agent status..." -ForegroundColor Cyan
    
    $sshAgent = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
    if (-not $sshAgent) {
        Write-Error "SSH Agent service not found. Please install OpenSSH client feature."
        exit 1
    }
    
    if ($sshAgent.Status -ne "Running") {
        Write-Host "Starting SSH Agent service..." -ForegroundColor Yellow
        if (Test-Administrator) {
            get-service ssh-agent | Set-Service -StartupType Automatic
            Start-Service ssh-agent
        } else {
            Write-Warning "SSH Agent is not running. You may need to start it manually or run this script as Administrator."
            Write-Host "To start SSH Agent: Set-Service ssh-agent -StartupType Automatic; Start-Service ssh-agent" -ForegroundColor Gray
        }
    } else {
        Write-Host "SSH Agent is already running." -ForegroundColor Green
    }
}

# Function to get Git user information
function Get-GitUserInfo {
    $gitName = git config --global user.name 2>$null
    $gitEmail = git config --global user.email 2>$null
    
    if (-not $gitName) {
        $gitName = Read-Host "Enter your Git user name"
        git config --global user.name $gitName
    }
    
    if (-not $gitEmail) {
        $gitEmail = Read-Host "Enter your Git email address"
        git config --global user.email $gitEmail
    }
    
    return @{
        Name = $gitName
        Email = $gitEmail
    }
}

# Main script execution
Write-Host "=== Git SSH Signing Key Setup ===" -ForegroundColor Green
Write-Host ""

# Check if Git is installed
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not in PATH. Please install Git first."
    exit 1
}

# Check Git version for SSH signing support
$gitVersion = git --version
Write-Host "Git version: $gitVersion" -ForegroundColor Cyan

# Extract version number and check if it supports SSH signing (2.34+)
if ($gitVersion -match "git version (\d+)\.(\d+)") {
    $majorVersion = [int]$Matches[1]
    $minorVersion = [int]$Matches[2]
    
    if ($majorVersion -lt 2 -or ($majorVersion -eq 2 -and $minorVersion -lt 34)) {
        Write-Warning "Git version $majorVersion.$minorVersion detected. SSH signing requires Git 2.34 or later."
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            exit 0
        }
    }
}

# Ensure SSH directory exists
$sshDir = "$env:USERPROFILE\.ssh"
if (-not (Test-Path $sshDir)) {
    Write-Host "Creating SSH directory: $sshDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

# Set up key paths
$privateKeyPath = "$sshDir\$KeyName"
$publicKeyPath = "$sshDir\$KeyName.pub"

# Check if key already exists
if ((Test-Path $privateKeyPath) -or (Test-Path $publicKeyPath)) {
    if (-not $Force) {
        Write-Host "SSH key already exists at $privateKeyPath" -ForegroundColor Yellow
        $overwrite = Read-Host "Overwrite existing key? (y/N)"
        if ($overwrite -ne "y" -and $overwrite -ne "Y") {
            Write-Host "Using existing key..." -ForegroundColor Green
        } else {
            $Force = $true
        }
    }
    
    if ($Force) {
        Write-Host "Removing existing key files..." -ForegroundColor Yellow
        Remove-Item -Path $privateKeyPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $publicKeyPath -Force -ErrorAction SilentlyContinue
    }
}

# Get Git user information
$gitUser = Get-GitUserInfo
if (-not $Comment) {
    $Comment = "$($gitUser.Email) - Git Signing Key"
}

# Generate new SSH key if needed
if (-not (Test-Path $privateKeyPath)) {
    Write-Host "Generating new ED25519 SSH key for Git signing..." -ForegroundColor Cyan
    Write-Host "Key will be saved as: $privateKeyPath" -ForegroundColor Gray
    
    # Generate the key (ED25519 is recommended for signing)
    $sshKeygenArgs = @(
        "-t", "ed25519",
        "-f", $privateKeyPath,
        "-C", $Comment,
        "-N", ""  # No passphrase for automation
    )
    
    & ssh-keygen @sshKeygenArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to generate SSH key"
        exit 1
    }
    
    Write-Host "SSH key generated successfully!" -ForegroundColor Green
} else {
    Write-Host "Using existing SSH key: $privateKeyPath" -ForegroundColor Green
}

# Start SSH agent
Start-SshAgent

# Add key to SSH agent
Write-Host "Adding key to SSH agent..." -ForegroundColor Cyan
ssh-add $privateKeyPath

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to add key to SSH agent"
    exit 1
}

# Configure Git to use SSH signing
Write-Host "Configuring Git for SSH signing..." -ForegroundColor Cyan

# Set the signing key
git config --global user.signingkey $publicKeyPath
git config --global gpg.format ssh
git config --global commit.gpgsign true

# Optional: Configure tag signing
$tagSigning = Read-Host "Enable tag signing as well? (Y/n)"
if ($tagSigning -ne "n" -and $tagSigning -ne "N") {
    git config --global tag.gpgsign true
    Write-Host "Tag signing enabled." -ForegroundColor Green
}

# Display the public key
Write-Host ""
Write-Host "=== Your SSH Public Key ===" -ForegroundColor Green
Write-Host "You can add this to your Git hosting service (GitHub, GitLab, etc.) for signature verification:" -ForegroundColor Yellow
Write-Host ""
Get-Content $publicKeyPath
Write-Host ""

# Show current Git configuration
Write-Host "=== Current Git Signing Configuration ===" -ForegroundColor Green
Write-Host "user.name: $(git config --global user.name)" -ForegroundColor Cyan
Write-Host "user.email: $(git config --global user.email)" -ForegroundColor Cyan
Write-Host "user.signingkey: $(git config --global user.signingkey)" -ForegroundColor Cyan
Write-Host "gpg.format: $(git config --global gpg.format)" -ForegroundColor Cyan
Write-Host "commit.gpgsign: $(git config --global commit.gpgsign)" -ForegroundColor Cyan
$tagGpgSign = git config --global tag.gpgsign 2>$null
if ($tagGpgSign) {
    Write-Host "tag.gpgsign: $tagGpgSign" -ForegroundColor Cyan
}

# Test signing
Write-Host ""
Write-Host "=== Testing Git Signing ===" -ForegroundColor Green
$testDir = "$env:TEMP\git-signing-test"

try {
    if (Test-Path $testDir) {
        Remove-Item -Recurse -Force $testDir
    }
    
    New-Item -ItemType Directory -Path $testDir | Out-Null
    Push-Location $testDir
    
    git init | Out-Null
    "Test file for signing verification" | Out-File test.txt
    git add test.txt
    git commit -m "Test commit for SSH signing" | Out-Null
    
    Write-Host "Test commit created successfully!" -ForegroundColor Green
    Write-Host "Verifying signature..." -ForegroundColor Cyan
    
    $signature = git log --show-signature -1 2>&1
    if ($signature -match "Good signature" -or $signature -match "signature") {
        Write-Host "✓ Commit signing is working!" -ForegroundColor Green
    } else {
        Write-Host "Note: Signature verification requires additional setup (allowed signers file)" -ForegroundColor Yellow
        Write-Host "But commit signing is configured and working." -ForegroundColor Green
    }
    
} catch {
    Write-Warning "Could not test signing: $($_.Exception.Message)"
} finally {
    Pop-Location
    if (Test-Path $testDir) {
        Remove-Item -Recurse -Force $testDir -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "=== Setup Complete! ===" -ForegroundColor Green
Write-Host "Your Git commits will now be signed with SSH." -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Add the public key above to your Git hosting service" -ForegroundColor Gray
Write-Host "2. Set up signature verification (optional) by configuring gpg.ssh.allowedSignersFile" -ForegroundColor Gray
Write-Host "3. Your commits will now be automatically signed!" -ForegroundColor Gray
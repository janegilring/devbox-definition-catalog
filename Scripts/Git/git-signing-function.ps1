# Add this function to your PowerShell profile for easy access
# To add to profile: Add-Content $PROFILE -Value (Get-Content git-signing-function.ps1)

function New-GitSigningKey {
    <#
    .SYNOPSIS
    Creates a new SSH key for Git commit signing and configures Git to use it.
    
    .DESCRIPTION
    This function generates a new ED25519 SSH key, adds it to the SSH agent, 
    and configures Git to use SSH signing for commits.
    
    .PARAMETER Comment
    Comment for the SSH key. If not provided, uses Git email and current date.
    
    .PARAMETER Force
    Overwrite existing key if it exists.
    
    .EXAMPLE
    New-GitSigningKey
    
    .EXAMPLE
    New-GitSigningKey -Comment "My signing key for work projects"
    #>
    
    param(
        [string]$Comment = "",
        [switch]$Force
    )
    
    # Check Git email and auto-configure if needed
    $gitEmail = git config --global user.email 2>$null
    if (-not $gitEmail) {
        Write-Host "🔍 Git email not configured. Attempting auto-detection..." -ForegroundColor Yellow
        
        # Try to auto-detect email from Entra ID
        try {
            $upnOutput = whoami /upn 2>$null
            if ($upnOutput -and $upnOutput -match '\S+@\S+\.\S+') {
                $detectedEmail = $upnOutput.Trim()
                Write-Host "✅ Detected email from Entra ID UPN: $detectedEmail" -ForegroundColor Green
                $confirm = Read-Host "Use this email for Git? (Y/n)"
                if ($confirm -ne "n" -and $confirm -ne "N") {
                    git config --global user.email $detectedEmail
                    $gitEmail = $detectedEmail
                    Write-Host "✅ Git email configured: $gitEmail" -ForegroundColor Green
                }
            }
        }
        catch {
            Write-Verbose "Could not auto-detect email: $($_.Exception.Message)"
        }
        
        # If still no email, prompt user
        if (-not $gitEmail) {
            $gitEmail = Read-Host "Enter your Git email address"
            if ($gitEmail) {
                git config --global user.email $gitEmail
                Write-Host "✅ Git email configured: $gitEmail" -ForegroundColor Green
            } else {
                Write-Error "Git email is required for signing key setup"
                return
            }
        }
    }
    
    # Check and auto-configure Git username if needed
    $gitName = git config --global user.name 2>$null
    if (-not $gitName) {
        Write-Host "🔍 Git name not configured. Attempting auto-detection..." -ForegroundColor Yellow
        
        try {
            # Try to get display name from Windows identity
            $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            if ($identity.Name -match "AzureAD\\(.+)") {
                $detectedName = $Matches[1]
                Write-Host "✅ Detected username from Entra ID: $detectedName" -ForegroundColor Green
                $confirmName = Read-Host "Use '$detectedName' as Git display name? (Y/n) or enter preferred name"
                $gitName = if ($confirmName -and $confirmName -ne "y" -and $confirmName -ne "Y") { $confirmName } else { $detectedName }
                git config --global user.name $gitName
                Write-Host "✅ Git name configured: $gitName" -ForegroundColor Green
            }
        }
        catch {
            Write-Verbose "Could not auto-detect name: $($_.Exception.Message)"
        }
        
        # If still no name, prompt user
        if (-not $gitName) {
            $gitName = Read-Host "Enter your Git display name"
            if ($gitName) {
                git config --global user.name $gitName
                Write-Host "✅ Git name configured: $gitName" -ForegroundColor Green
            }
        }
    }
    
    # Set default comment
    if (-not $Comment) {
        $Comment = "$gitEmail - Git Signing $(Get-Date -Format 'yyyy-MM-dd')"
    }
    
    # Generate unique key name
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $keyName = "git_signing_$timestamp"
    $sshDir = "$env:USERPROFILE\.ssh"
    $privateKey = "$sshDir\$keyName"
    $publicKey = "$sshDir\$keyName.pub"
    
    # Ensure SSH directory exists
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }
    
    Write-Host "🔑 Creating new Git signing key..." -ForegroundColor Green
    Write-Host "📍 Location: $privateKey" -ForegroundColor Cyan
    
    # Generate SSH key
    & ssh-keygen -t ed25519 -f $privateKey -C $Comment -N ""
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to generate SSH key"
        return
    }
    
    # Add to SSH agent
    Write-Host "🔄 Adding to SSH agent..." -ForegroundColor Cyan
    & ssh-add $privateKey
    
    # Configure Git
    Write-Host "⚙️ Configuring Git..." -ForegroundColor Cyan
    git config --global user.signingkey $publicKey
    git config --global gpg.format ssh
    git config --global commit.gpgsign true
    
    # Show results
    Write-Host ""
    Write-Host "✅ Git signing configured successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Public key (add to GitHub/GitLab for verification):" -ForegroundColor Yellow
    Write-Host (Get-Content $publicKey) -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 Current Git signing config:" -ForegroundColor Yellow
    Write-Host "  user.signingkey: $(git config --global user.signingkey)" -ForegroundColor Gray
    Write-Host "  gpg.format: $(git config --global gpg.format)" -ForegroundColor Gray
    Write-Host "  commit.gpgsign: $(git config --global commit.gpgsign)" -ForegroundColor Gray
}

# Alias for shorter command
Set-Alias -Name gitkey -Value New-GitSigningKey
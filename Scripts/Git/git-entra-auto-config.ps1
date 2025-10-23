# Enhanced Git SSH Signing Setup with Entra ID Auto-Detection
# Automatically configures Git username and email for Entra ID joined machines

function Get-EntraIdUserInfo {
    <#
    .SYNOPSIS
    Attempts to automatically detect Entra ID user information for Git configuration.
    #>
    
    $userInfo = @{
        Email = $null
        Name = $null
        Source = "Unknown"
    }
    
    try {
        # Method 1: Try to get UPN (User Principal Name) from whoami
        $upnOutput = whoami /upn 2>$null
        if ($upnOutput -and $upnOutput -match '\S+@\S+\.\S+') {
            $userInfo.Email = $upnOutput.Trim()
            $userInfo.Source = "UPN (whoami)"
            Write-Host "✅ Found email from UPN: $($userInfo.Email)" -ForegroundColor Green
        }
    }
    catch {
        Write-Verbose "Could not get UPN: $($_.Exception.Message)"
    }
    
    try {
        # Method 2: Try to get display name from Windows identity
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        if ($identity.Name -match "AzureAD\\(.+)") {
            $username = $Matches[1]
            
            # If we don't have an email yet, try to construct one
            if (-not $userInfo.Email -and $username -match '^[a-zA-Z0-9._%+-]+$') {
                # This is a fallback - we'll ask user to confirm
                $userInfo.Email = "$username@yourdomain.com"
                $userInfo.Source = "Windows Identity (needs confirmation)"
            }
            
            # Use the username as display name if we don't have a better one
            if (-not $userInfo.Name) {
                $userInfo.Name = $username
                Write-Host "✅ Found username from Windows Identity: $($userInfo.Name)" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Verbose "Could not get Windows identity info: $($_.Exception.Message)"
    }
    
    try {
        # Method 3: Try to get info from environment variables
        if (-not $userInfo.Email) {
            $possibleEmails = @($env:USERPRINCIPALNAME, $env:USERNAME + "@" + $env:USERDNSDOMAIN)
            foreach ($email in $possibleEmails) {
                if ($email -and $email -match '\S+@\S+\.\S+') {
                    $userInfo.Email = $email
                    $userInfo.Source = "Environment Variables"
                    Write-Host "✅ Found email from environment: $($userInfo.Email)" -ForegroundColor Green
                    break
                }
            }
        }
        
        if (-not $userInfo.Name) {
            $fullName = $env:USERNAME
            if ($fullName) {
                $userInfo.Name = $fullName
                Write-Host "✅ Found name from environment: $($userInfo.Name)" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Verbose "Could not get environment variable info: $($_.Exception.Message)"
    }
    
    try {
        # Method 4: Try Azure CLI if available (for more detailed info)
        if (Get-Command az -ErrorAction SilentlyContinue) {
            $azAccount = az account show --query "user" 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($azAccount -and $azAccount.name) {
                if (-not $userInfo.Email -and $azAccount.name -match '\S+@\S+\.\S+') {
                    $userInfo.Email = $azAccount.name
                    $userInfo.Source = "Azure CLI"
                    Write-Host "✅ Found email from Azure CLI: $($userInfo.Email)" -ForegroundColor Green
                }
            }
        }
    }
    catch {
        Write-Verbose "Could not get Azure CLI info: $($_.Exception.Message)"
    }
    
    return $userInfo
}

function Set-GitUserConfig {
    <#
    .SYNOPSIS
    Automatically configures Git user name and email, with prompts for missing info.
    #>
    
    param(
        [switch]$Force
    )
    
    Write-Host "🔍 Auto-detecting Entra ID user information..." -ForegroundColor Cyan
    
    # Get current Git config
    $currentName = git config --global user.name 2>$null
    $currentEmail = git config --global user.email 2>$null
    
    # Auto-detect user info
    $detectedInfo = Get-EntraIdUserInfo
    
    # Determine what to use for email
    $emailToUse = $currentEmail
    if (-not $emailToUse -or $Force) {
        if ($detectedInfo.Email -and $detectedInfo.Source -ne "Windows Identity (needs confirmation)") {
            $emailToUse = $detectedInfo.Email
            Write-Host "📧 Using detected email: $emailToUse" -ForegroundColor Green
        } elseif ($detectedInfo.Email) {
            # Need confirmation for constructed email
            Write-Host "📧 Detected possible email: $($detectedInfo.Email)" -ForegroundColor Yellow
            $confirmEmail = $true #Read-Host "Is this correct? Press Enter to accept, or type the correct email"
            $emailToUse = if ($confirmEmail) { $confirmEmail } else { $detectedInfo.Email }
        } else {
            # Prompt for email
            $emailToUse = Read-Host "Enter your Git email address"
        }
    }
    
    # Determine what to use for name
    $nameToUse = $currentName
    if (-not $nameToUse -or $Force) {
        if ($detectedInfo.Name) {
            Write-Host "👤 Detected name: $($detectedInfo.Name)" -ForegroundColor Yellow
            $confirmName = $detectedInfo.Name #Read-Host "Press Enter to use '$($detectedInfo.Name)' or type your preferred display name"
            $nameToUse = if ($confirmName) { $confirmName } else { $detectedInfo.Name }
        } else {
            $nameToUse =$detectedInfo.Name #Read-Host "Enter your Git display name"
        }
    }
    
    # Set Git configuration
    if ($emailToUse) {
        git config --global user.email $emailToUse
        Write-Host "✅ Set Git email: $emailToUse" -ForegroundColor Green
    }
    
    if ($nameToUse) {
        git config --global user.name $nameToUse
        Write-Host "✅ Set Git name: $nameToUse" -ForegroundColor Green
    }
    
    return @{
        Name = $nameToUse
        Email = $emailToUse
    }
}

function New-GitSigningKeyWithAutoConfig {
    <#
    .SYNOPSIS
    Creates a new SSH key for Git commit signing with automatic Entra ID user detection.
    
    .DESCRIPTION
    This function automatically detects Entra ID user information, configures Git user settings,
    generates a new ED25519 SSH key, adds it to the SSH agent, and configures Git to use SSH signing.
    
    .PARAMETER Comment
    Comment for the SSH key. If not provided, uses detected email and current date.
    
    .PARAMETER Force
    Overwrite existing key and Git config if they exist.
    
    .PARAMETER SkipUserConfig
    Skip automatic Git user configuration and only set up signing.
    
    .EXAMPLE
    New-GitSigningKeyWithAutoConfig
    
    .EXAMPLE
    New-GitSigningKeyWithAutoConfig -Force -Comment "My work signing key"
    #>
    
    param(
        [string]$Comment = "",
        [switch]$Force,
        [switch]$SkipUserConfig
    )
    
    Write-Host "🔑 Git SSH Signing Setup with Entra ID Auto-Detection" -ForegroundColor Green
    Write-Host ""
    
    # Configure Git user info unless skipped
    if (-not $SkipUserConfig) {
        $userConfig = Set-GitUserConfig -Force:$Force
        $gitEmail = $userConfig.Email
        $gitName = $userConfig.Name
    } else {
        $gitEmail = git config --global user.email 2>$null
        $gitName = git config --global user.name 2>$null
        
        if (-not $gitEmail) {
            Write-Error "Git email not configured and -SkipUserConfig specified. Configure email first or run without -SkipUserConfig."
            return
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
    
    Write-Host ""
    Write-Host "🔐 Generating SSH signing key..." -ForegroundColor Cyan
    Write-Host "📍 Location: $privateKey" -ForegroundColor Gray
    Write-Host "💬 Comment: $Comment" -ForegroundColor Gray
    
    # Generate SSH key
    & ssh-keygen -t ed25519 -f $privateKey -C $Comment -N ""
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to generate SSH key"
        return
    }
    
    # Add to SSH agent
    Write-Host "🔄 Adding to SSH agent..." -ForegroundColor Cyan
    & ssh-add $privateKey
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to add key to SSH agent. You may need to start SSH agent service."
    }
    
    # Configure Git for signing
    Write-Host "⚙️ Configuring Git for SSH signing..." -ForegroundColor Cyan
    git config --global user.signingkey $publicKey
    git config --global gpg.format ssh
    git config --global commit.gpgsign true
    
    # Show results
    Write-Host ""
    Write-Host "✅ Git signing configured successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "👤 Git User Configuration:" -ForegroundColor Yellow
    Write-Host "  Name: $gitName" -ForegroundColor White
    Write-Host "  Email: $gitEmail" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 Git Signing Configuration:" -ForegroundColor Yellow
    Write-Host "  Signing Key: $publicKey" -ForegroundColor White
    Write-Host "  Format: SSH" -ForegroundColor White
    Write-Host "  Auto-sign commits: Enabled" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 Public Key (add to GitHub/GitLab/Azure DevOps):" -ForegroundColor Yellow
    Write-Host ""
    Write-Host (Get-Content $publicKey) -ForegroundColor Cyan
    Write-Host ""
    
    # Instructions for adding to Git hosting services
    Write-Host "📚 Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Copy the public key above" -ForegroundColor White
    Write-Host "2. Add it to your Git hosting service:" -ForegroundColor White
    Write-Host "   • GitHub: Settings → SSH and GPG keys → New SSH key (type: Signing Key)" -ForegroundColor Gray
    Write-Host "   • GitLab: User Settings → SSH Keys → Add SSH key" -ForegroundColor Gray
    Write-Host "   • Azure DevOps: User Settings → SSH public keys → Add" -ForegroundColor Gray
    Write-Host "3. Your commits will now be automatically signed! 🎉" -ForegroundColor White
}

# Aliases for convenience
Set-Alias -Name gitkey-auto -Value New-GitSigningKeyWithAutoConfig
Set-Alias -Name git-setup-entra -Value New-GitSigningKeyWithAutoConfig
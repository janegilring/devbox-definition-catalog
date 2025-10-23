# Git SSH Signing Automation

This collection of scripts automates the process of creating SSH keys for Git commit signing and configuring Git to use them.

## Files Created

1. **`setup-git-signing.ps1`** - Full-featured setup script with testing and validation
2. **`quick-git-signing.ps1`** - Simple, fast key generation and configuration
3. **`setup-git-signing.bat`** - Batch file wrapper for easy execution
4. **`git-signing-function.ps1`** - PowerShell function for your profile

## Quick Start

### Option 1: Run the Quick Script
```powershell
.\quick-git-signing.ps1
```

### Option 2: Run the Full Setup Script
```powershell
.\setup-git-signing.ps1
```

### Option 3: Use the Batch File (Windows)
```cmd
setup-git-signing.bat
```

### Option 4: Add Function to PowerShell Profile
```powershell
# Add function to your profile
Add-Content $PROFILE -Value (Get-Content git-signing-function.ps1)

# Reload profile
. $PROFILE

# Use the function
New-GitSigningKey
# or use the alias
gitkey
```

## What These Scripts Do

1. **Check Prerequisites**
   - Verify Git is installed and supports SSH signing (v2.34+)
   - Ensure SSH agent service is running
   - Check/set Git user configuration

2. **Generate SSH Key**
   - Create a new ED25519 SSH key (recommended for signing)
   - Use a unique filename with timestamp
   - Add descriptive comment with email and date

3. **Configure SSH Agent**
   - Add the new key to SSH agent
   - Ensure key is available for signing

4. **Configure Git**
   - Set `user.signingkey` to the new public key
   - Set `gpg.format` to `ssh`
   - Enable `commit.gpgsign`
   - Optionally enable `tag.gpgsign`

5. **Verify Setup**
   - Create a test repository and commit
   - Verify signing is working
   - Display public key for adding to Git hosting services

## Script Parameters

### setup-git-signing.ps1
```powershell
.\setup-git-signing.ps1 [-KeyName "custom_key_name"] [-Comment "Custom comment"] [-Force]
```

- `-KeyName`: Custom name for the SSH key (default: id_ed25519_git_signing)
- `-Comment`: Custom comment for the key (default: email + "Git Signing Key")
- `-Force`: Overwrite existing key without prompting

### quick-git-signing.ps1
```powershell
.\quick-git-signing.ps1 [-KeyComment "Custom comment"]
```

- `-KeyComment`: Custom comment for the key

### New-GitSigningKey Function
```powershell
New-GitSigningKey [-Comment "Custom comment"] [-Force]
```

- `-Comment`: Custom comment for the key
- `-Force`: Overwrite existing key

## Prerequisites

- **Git 2.34 or later** (for SSH signing support)
- **OpenSSH client** (usually included with Windows 10/11)
- **PowerShell** (for running the scripts)

## After Running the Script

1. **Copy your public key** (displayed by the script)
2. **Add it to your Git hosting service:**
   - **GitHub**: Settings → SSH and GPG keys → New SSH key (choose "Signing Key" type)
   - **GitLab**: User Settings → SSH Keys → Add SSH key (check "Use this key for GitKraken Git GUI")
   - **Azure DevOps**: User Settings → SSH public keys → Add

3. **Your commits will now be automatically signed!**

## Troubleshooting

### "SSH Agent not running"
```powershell
# Start SSH agent service
Set-Service ssh-agent -StartupType Automatic
Start-Service ssh-agent
```

### "Git version too old"
Update Git to version 2.34 or later to support SSH signing.

### "Key not found in agent"
```powershell
# Add key manually
ssh-add ~/.ssh/your_key_name
```

### "Permission denied" errors
Run PowerShell as Administrator if needed.

## Manual Commands (if you prefer)

If you want to understand what the scripts do, here are the manual commands:

```powershell
# 1. Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/git_signing -C "your@email.com - Git Signing"

# 2. Add to SSH agent
ssh-add ~/.ssh/git_signing

# 3. Configure Git
git config --global user.signingkey ~/.ssh/git_signing.pub
git config --global gpg.format ssh
git config --global commit.gpgsign true

# 4. Optional: Enable tag signing
git config --global tag.gpgsign true
```

## Security Notes

- The scripts generate keys without passphrases for automation
- Keys are stored in your user profile's .ssh directory
- Only you have access to the private keys
- SSH agent manages key access securely
- You can add passphrases later if desired

## Example Output

```
🔑 Quick Git SSH Signing Setup

📁 SSH Directory: C:\Users\YourName\.ssh
🔐 Generating key: git_signing_20251021_105730
Generating public/private ed25519 key pair.
Your identification has been saved in C:\Users\YourName\.ssh\git_signing_20251021_105730
Your public key has been saved in C:\Users\YourName\.ssh\git_signing_20251021_105730.pub
✅ SSH key generated successfully!
🔄 Adding key to SSH agent...
Identity added: C:\Users\YourName\.ssh\git_signing_20251021_105730
⚙️ Configuring Git...

🎉 Setup Complete!

Configuration:
  Signing Key: C:\Users\YourName\.ssh\git_signing_20251021_105730.pub
  Format: SSH
  Auto-sign commits: Enabled

📋 Your public key (add to GitHub/GitLab):
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your@email.com - Git Signing 2025-10-21
```

---

*Created on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')*
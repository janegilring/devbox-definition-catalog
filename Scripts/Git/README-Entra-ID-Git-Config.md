# Git Configuration for Entra ID Joined Machines

## Automatic Configuration Methods

### 🚀 **Method 1: Enhanced Auto-Detection Script** (Recommended)

The `git-entra-auto-config.ps1` script automatically detects Entra ID user information:

```powershell
# Load and run the enhanced script
. .\git-entra-auto-config.ps1
New-GitSigningKeyWithAutoConfig
```

**What it auto-detects:**
- ✅ **Email**: From UPN (`whoami /upn`) → `admin@mngenvmcap363964.onmicrosoft.com`
- ✅ **Username**: From Windows Identity → `SystemAdministrator`
- ✅ **Domain info**: From environment variables if available

### 🔧 **Method 2: Enhanced Function** (Updated Original)

The updated `git-signing-function.ps1` now includes auto-detection:

```powershell
# Load the enhanced function
. .\git-signing-function.ps1
New-GitSigningKey
```

### ⚡ **Method 3: Quick Commands**

```powershell
# One-liner for immediate setup
iex (Get-Content git-entra-auto-config.ps1 -Raw); New-GitSigningKeyWithAutoConfig

# Or use the alias
. .\git-entra-auto-config.ps1; gitkey-auto
```

### 🖱️ **Method 4: Batch File** (Windows GUI)

Double-click: `setup-git-entra-auto.bat`

## Detection Methods Used

### 1. **UPN (User Principal Name)** - Primary Method
```powershell
whoami /upn
# Returns: admin@mngenvmcap363964.onmicrosoft.com
```

### 2. **Windows Identity** - Secondary Method
```powershell
[System.Security.Principal.WindowsIdentity]::GetCurrent().Name
# Returns: AzureAD\SystemAdministrator
```

### 3. **Environment Variables** - Fallback Method
```powershell
$env:USERPRINCIPALNAME
$env:USERNAME + "@" + $env:USERDNSDOMAIN
```

### 4. **Azure CLI** - If Available
```powershell
az account show --query "user.name"
```

## Manual Configuration (Traditional Method)

If you prefer manual configuration:

```powershell
# Configure Git user info manually
git config --global user.name "Your Display Name"
git config --global user.email "your.email@company.com"

# Then run any signing setup script
.\quick-git-signing.ps1
```

## PowerShell Profile Integration

Add to your PowerShell profile for permanent access:

```powershell
# Add the functions to your profile
Add-Content $PROFILE -Value (Get-Content git-entra-auto-config.ps1 -Raw)

# Reload profile
. $PROFILE

# Then use anytime
gitkey-auto
# or
git-setup-entra
```

## Common Entra ID Scenarios

### 🏢 **Corporate Domain** 
- UPN: `john.doe@company.com`
- Auto-detected and used directly

### 🌐 **Azure AD B2B Guest**
- UPN: `guest_company.com#EXT#@yourtenant.onmicrosoft.com`
- Script will prompt for preferred email

### 🔧 **On-Premises Sync**
- UPN: `john.doe@internal.company.com`
- May need manual confirmation for external Git services

### 📱 **Personal Microsoft Account**
- UPN: `personal@outlook.com`
- Auto-detected and used directly

## Security Considerations

1. **Email Verification**: Scripts always prompt for confirmation when email is constructed
2. **Key Security**: ED25519 keys are generated without passphrases for automation
3. **SSH Agent**: Keys are automatically added to SSH agent for session persistence
4. **Domain Privacy**: Scripts detect but don't store unnecessary domain information

## Troubleshooting

### "Could not detect email"
```powershell
# Manually check what's available
whoami /upn
[System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$env:USERPRINCIPALNAME
```

### "Permission denied"
- Run PowerShell as Administrator if needed
- Check if SSH agent service is running

### "Invalid email format"
- The script will prompt for manual entry
- Common with complex B2B guest accounts

## Example Output

```
🔍 Auto-detecting Entra ID user information...
✅ Found email from UPN: admin@mngenvmcap363964.onmicrosoft.com
✅ Found username from Windows Identity: SystemAdministrator
📧 Using detected email: admin@mngenvmcap363964.onmicrosoft.com
👤 Using detected name: SystemAdministrator

🔐 Generating SSH signing key...
📍 Location: C:\Users\SystemAdministrator\.ssh\git_signing_20251021_112847
✅ SSH key generated successfully!
🔄 Adding to SSH agent...
⚙️ Configuring Git for SSH signing...

✅ Git signing configured successfully!

👤 Git User Configuration:
  Name: SystemAdministrator
  Email: admin@mngenvmcap363964.onmicrosoft.com

📋 Public Key (add to GitHub/GitLab/Azure DevOps):
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... admin@mngenvmcap363964.onmicrosoft.com - Git Signing 2025-10-21
```

---

*This automation works on Windows 10/11 machines joined to Entra ID (Azure AD) and provides seamless Git configuration for enterprise environments.*
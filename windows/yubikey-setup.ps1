<#
yubikey-setup.ps1: YubiKey (e.g. YubiKey 5C NFC) on Windows 11, as far as Windows allows.
Run in an administrator PowerShell:
    Set-ExecutionPolicy -Scope Process Bypass
    .\yubikey-setup.ps1                 status and what to do next
    .\yubikey-setup.ps1 -Tools          Yubico Authenticator (set the FIDO2 PIN)
    .\yubikey-setup.ps1 -RecoveryAdmin  a spare local admin account (before Yubico Login!)
    .\yubikey-setup.ps1 -BitLockerPin   disk: BitLocker with TPM + startup PIN, recovery key saved
    .\yubikey-setup.ps1 -LoginTool      open the Yubico Login for Windows download (local accounts)

What Windows can and can't do with a YubiKey (README.md, github.com/darktime78/yubikey-setup):
  - The system disk (BitLocker): a YubiKey can't unlock it before boot. TPM + PIN is the
    strong option; the YubiKey can't replace it.
  - Windows sign-in, local account: Yubico Login for Windows (x86 PCs, local accounts).
  - Windows sign-in, Microsoft account: not with a YubiKey (only work accounts in Entra ID).
    Use the YubiKey as a passkey for the Microsoft account itself, online.
#>
#Requires -RunAsAdministrator
param(
    [switch]$Tools,
    [switch]$RecoveryAdmin,
    [switch]$BitLockerPin,
    [switch]$LoginTool
)
$ErrorActionPreference = 'Stop'

function Say($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)  { Write-Host " ok  $m" -ForegroundColor Green }
function Warn($m){ Write-Host "warning: $m" -ForegroundColor Yellow }

$drive = $env:SystemDrive
$edition = (Get-CimInstance Win32_OperatingSystem).Caption
$me = Get-LocalUser -Name $env:USERNAME -ErrorAction SilentlyContinue

function Show-Status {
    Say "Windows: $edition"
    if ($me) {
        $kind = switch ($me.PrincipalSource) {
            'MicrosoftAccount' { 'Microsoft account' }
            'Local'            { 'local account' }
            default            { "$($me.PrincipalSource)" }
        }
        Say "You ($env:USERNAME): $kind"
    } else {
        Say "You ($env:USERNAME): work / domain account (Entra ID or AD): ask your admin about security keys"
    }
    try {
        $v = Get-BitLockerVolume -MountPoint $drive
        $prot = ($v.KeyProtector | ForEach-Object { $_.KeyProtectorType }) -join ', '
        Say "BitLocker on ${drive}: $($v.ProtectionStatus) ($prot)"
    } catch {
        Say "BitLocker: not available ($edition has only 'Device encryption' at most)"
    }
    $tpm = Get-Tpm
    Say "TPM: present=$($tpm.TpmPresent) ready=$($tpm.TpmReady)"
    $admins = Get-LocalGroupMember -Group Administrators -ErrorAction SilentlyContinue |
        Where-Object { $_.ObjectClass -eq 'User' }
    Say "Local administrators: $(($admins | ForEach-Object { $_.Name }) -join ', ')"
    ""
    "Next steps:"
    "  1. .\yubikey-setup.ps1 -Tools          set the key's FIDO2 PIN"
    "  2. Microsoft account: https://account.microsoft.com/security -> Advanced security"
    "     options -> Add a new way to sign in -> Security key (the YubiKey, USB-C or NFC)"
    "  3. .\yubikey-setup.ps1 -BitLockerPin   PIN before Windows starts (Pro / Enterprise)"
    if ($me -and $me.PrincipalSource -eq 'Local') {
        "  4. .\yubikey-setup.ps1 -RecoveryAdmin, then -LoginTool: YubiKey for Windows sign-in"
    }
}

function Install-Tools {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Say "Yubico Authenticator (FIDO2 PIN, passkeys, OATH codes)"
        winget install --id Yubico.Authenticator -e --accept-source-agreements --accept-package-agreements
    } else {
        Start-Process 'https://www.yubico.com/products/yubico-authenticator/'
    }
    "Set the FIDO2 PIN: Yubico Authenticator -> Passkeys -> set PIN, or"
    "Settings -> Accounts -> Sign-in options -> Security key -> Manage."
}

function New-RecoveryAdmin {
    $name = Read-Host 'Name of the spare admin account [RecoveryAdmin]'
    if (-not $name) { $name = 'RecoveryAdmin' }
    if (Get-LocalUser -Name $name -ErrorAction SilentlyContinue) { Ok "$name exists already"; return }
    $pw = Read-Host "Password for $name (write it down, keep it safe)" -AsSecureString
    New-LocalUser -Name $name -Password $pw -PasswordNeverExpires -Description 'Spare admin (YubiKey lockout)' | Out-Null
    Add-LocalGroupMember -Group Administrators -Member $name
    Ok "$name is a local administrator: sign in with it once to test"
}

function Set-BitLockerPin {
    if (-not (Get-Command manage-bde -ErrorAction SilentlyContinue)) {
        throw "No BitLocker on $edition (Home has only Device encryption, without a startup PIN)"
    }
    $tpm = Get-Tpm
    if (-not $tpm.TpmReady) { throw 'The TPM is not ready (enable it in the UEFI setup)' }

    # allow TPM + PIN at startup (the same as the group policy "Require additional
    # authentication at startup": TPM allowed, PIN allowed)
    $fve = 'HKLM:\SOFTWARE\Policies\Microsoft\FVE'
    New-Item -Path $fve -Force | Out-Null
    $policy = @{ UseAdvancedStartup = 1; EnableBDEWithNoTPM = 0; UseTPM = 2; UseTPMPIN = 2; UseTPMKey = 2; UseTPMKeyPIN = 2 }
    foreach ($k in $policy.Keys) { Set-ItemProperty -Path $fve -Name $k -Value $policy[$k] -Type DWord }
    Ok 'policy: startup PIN allowed'

    $v = Get-BitLockerVolume -MountPoint $drive
    if ($v.VolumeStatus -eq 'FullyDecrypted') {
        Say "BitLocker is off on ${drive}: turning it on with TPM + PIN"
        $pin = Read-Host 'Startup PIN (6-20 digits)' -AsSecureString
        Enable-BitLocker -MountPoint $drive -EncryptionMethod XtsAes256 -UsedSpaceOnly -TpmAndPinProtector -Pin $pin | Out-Null
    } else {
        Say "BitLocker is on: adding TPM + PIN (it replaces TPM-only); type the PIN twice"
        manage-bde -protectors -add $drive -TPMAndPIN
        if ($LASTEXITCODE -ne 0) { throw 'manage-bde failed' }
    }
    $v = Get-BitLockerVolume -MountPoint $drive
    if (-not ($v.KeyProtector | Where-Object KeyProtectorType -eq 'RecoveryPassword')) {
        Add-BitLockerKeyProtector -MountPoint $drive -RecoveryPasswordProtector | Out-Null
        $v = Get-BitLockerVolume -MountPoint $drive
    }
    $rec = $v.KeyProtector | Where-Object KeyProtectorType -eq 'RecoveryPassword' | Select-Object -First 1
    Write-Host ''
    Write-Host "RECOVERY KEY (ID $($rec.KeyProtectorId)):" -ForegroundColor Yellow
    Write-Host "  $($rec.RecoveryPassword)" -ForegroundColor Yellow
    $out = Read-Host 'Save it to a file? Path on a USB stick, e.g. E:\bitlocker-recovery.txt (empty: no)'
    if ($out) {
        "BitLocker recovery key for $env:COMPUTERNAME $drive`r`nID: $($rec.KeyProtectorId)`r`nKey: $($rec.RecoveryPassword)" |
            Set-Content -Path $out -Encoding ascii
        Ok "saved: $out (not on this disk!)"
    }
    Warn 'Keep the recovery key off this PC (paper, password manager). A Microsoft account'
    Warn 'also keeps a copy at https://account.microsoft.com/devices/recoverykey'
    Ok 'restart: Windows asks for the PIN before it starts'
}

function Open-LoginTool {
    if (-not $me -or $me.PrincipalSource -ne 'Local') {
        Warn 'Yubico Login for Windows works only with local accounts, and you are not on one.'
        Warn 'For a Microsoft account use the passkey (step 2 in the status).'
        return
    }
    $admins = Get-LocalGroupMember -Group Administrators | Where-Object { $_.ObjectClass -eq 'User' }
    if (@($admins).Count -lt 2) {
        Warn 'Create a spare admin first: .\yubikey-setup.ps1 -RecoveryAdmin'
        Warn 'A lost or broken YubiKey with Yubico Login means no way in otherwise.'
        return
    }
    "Yubico Login for Windows: configure it for $env:USERNAME, with TWO YubiKeys if you can,"
    "and save the recovery code it shows. Your password stops working for that account."
    Start-Process 'https://www.yubico.com/products/computer-login-tools/'
}

if ($Tools)         { Install-Tools }
if ($RecoveryAdmin) { New-RecoveryAdmin }
if ($BitLockerPin)  { Set-BitLockerPin }
if ($LoginTool)     { Open-LoginTool }
if (-not ($Tools -or $RecoveryAdmin -or $BitLockerPin -or $LoginTool)) { Show-Status }

# YubiKey 5C NFC: disk unlock and login

What the key can do on Arch Linux, macOS and Windows 11, and scripts that set it up.
Your passwords keep working everywhere unless you turn them off yourself.

**These scripts don't encrypt anything.** They add the YubiKey as another way to unlock
a disk that is already encrypted (LUKS2 on Arch, FileVault on macOS) and to log in. For
Arch, the encrypted disk is made at install time by `arch-disk.sh` (next section). An
existing unencrypted install can be encrypted in place with `cryptsetup reencrypt
--encrypt` from a live USB, after a full backup.

## Get it

Part of [darktime78/dotfiles](https://github.com/darktime78/dotfiles) (folder `yubikey/`,
the dotfiles' `install.sh` puts the command on your PATH), or alone:

```sh
git clone https://github.com/darktime78/yubikey-setup ~/yubikey-setup
~/yubikey-setup/install.sh        # links yubikey-setup (Arch) / yubikey-setup-mac (macOS)
```

Windows: download the repository as a ZIP and run `windows\yubikey-setup.ps1`.

| | Disk at boot | Login / lock screen | Admin (sudo) |
|---|---|---|---|
| **Arch Linux** | yes: key + PIN unlocks LUKS2 (`yubikey-setup disk`) | yes: password + touch, or touch only (`yubikey-setup login`) | yes: touch (`yubikey-setup sudo`) |
| **macOS Ventura+** | Apple silicon: yes (PIN at the FileVault screen). Intel: no, password | yes: key + PIN (`yubikey-setup-mac setup`) | the admin dialogs accept the key |
| **Windows 11** | no: BitLocker can't use a key for the system disk; TPM + PIN instead (`-BitLockerPin`) | local account: Yubico Login for Windows. Microsoft account: no | – |

The YubiKey has separate parts that these setups use: **FIDO2** (Arch: disk and login;
web passkeys), **PIV smart card** (macOS login), **OTP** (Yubico Login for Windows).
Each has its own PIN:

| PIN | Default | Used for | Set with |
|---|---|---|---|
| FIDO2 PIN | none | Arch disk unlock, passkeys | `yubikey-setup pin`, Yubico Authenticator |
| PIV PIN / PUK | 123456 / 12345678 | macOS login | `yubikey-setup-mac setup` |

8 wrong FIDO2 PINs lock FIDO2; 3 wrong PIV PINs block the PIN (the PUK unblocks it).

## Before you start: do not lock yourself out

1. **Two keys** are the real safety net. Register the second one everywhere right after
   the first (`yubikey-setup add-key`, `yubikey-setup-mac pair` on each key).
2. **Keep the passwords**: the LUKS passphrase, your login password, the BitLocker
   recovery key. Nothing here removes them; write them down and store them off the device.
3. **Keep a session open** while changing login (Arch: a second terminal with `sudo -s`).
4. NFC is for phones: the same key signs in to accounts on an Android phone or iPhone.

## A new encrypted Arch install (with the YubiKey)

Boot the Arch ISO in UEFI mode, connect to the network (`iwctl` for Wi-Fi), then:

```sh
curl -LO https://raw.githubusercontent.com/darktime78/dotfiles/master/install/arch-disk.sh
bash arch-disk.sh                 # 1. wipe a disk, encrypt it, optional YubiKey
pacstrap -K /mnt base linux linux-firmware          # 2. the base system
curl -LO https://raw.githubusercontent.com/darktime78/dotfiles/master/install/arch-bootstrap.sh
bash arch-bootstrap.sh            # 3. everything else, boot set up for the key
```

**1. `arch-disk.sh`** asks for the disk (you type its name twice; everything on it is
deleted), the filesystem and whether to add the YubiKey, then makes:

```
/dev/nvme0n1p1   1 GiB   EFI, FAT32, not encrypted   /mnt/boot   (boot loader, kernels)
/dev/nvme0n1p2   rest    LUKS2, argon2id, your passphrase
                 └ /dev/mapper/cryptroot  btrfs (@ @home @log @pkg @snapshots) or ext4   /mnt
```

- The **passphrase** is the main key and stays valid forever: write it down. At boot the
  keyboard is US until the system has your layout, so avoid letters that move on it.
- On an SSD, TRIM is turned on in the LUKS header (`--allow-discards --persistent`).
- **YubiKey**: plug it in when asked. A new key has no FIDO2 PIN; the script offers to set
  one (`ykman fido access change-pin`). Then: passphrase, PIN, touch. If that fails, the
  script goes on without the key; add it later with `yubikey-setup disk`.

**2. `pacstrap`** installs the base system onto `/mnt`.

**3. `arch-bootstrap.sh`** finds the encryption and the YubiKey by itself: systemd
initramfs with `sd-encrypt`, kernel line `rd.luks.name=…` and, with the key,
`rd.luks.options=…=fido2-device=auto`, plus `libfido2`, `pam-u2f`, `yubikey-manager`.

**Every boot**: key in → type its PIN, touch it. No key → after ~30 s the passphrase
prompt. **After the first login**:

```sh
sudo cryptsetup luksHeaderBackup /dev/nvme0n1p2 --header-backup-file luks-header.img
# copy luks-header.img to a USB stick: a damaged header loses the data, passphrase or not
yubikey-setup add-key    # the second YubiKey (strongly recommended)
yubikey-setup sudo       # and login, if you want (below)
```

Without the key at install time: install the same way, then after the first boot
`yubikey-setup pin && yubikey-setup disk` adds it.

## Arch Linux (an installed system)

```sh
yubikey-setup pin      # 1. FIDO2 PIN (needed for the disk)
yubikey-setup disk     # 2. disk unlock at boot
yubikey-setup sudo     # 3. sudo: touch instead of the password (tested at once)
yubikey-setup login    # 4. tty login + lock screen: password AND touch
yubikey-setup add-key  # 5. the second key, for disk and login
yubikey-setup status
```

**Disk** (`disk`): enrolls the key into a free LUKS2 key slot with
`systemd-cryptenroll`, PIN and touch required. The passphrase slot stays. At boot:
key in, type its PIN, touch it. No key: after about 30 seconds the passphrase prompt
comes, as before. For this the initramfs must be systemd style: if yours is the busybox
style (`udev … encrypt`), the script shows the new `HOOKS=(… systemd … sd-encrypt …)` and
asks before it changes it, rewrites the kernel line (`cryptdevice=` → `rd.luks.name=`, plus
`rd.luks.options=…=fido2-device=auto`) in the systemd-boot entries, GRUB or
`/etc/kernel/cmdline`, and runs `mkinitcpio -P`. Backups, including the LUKS header, go to
`/root/yubikey-backup/DATE/`: copy the header file to a USB stick.

**Login** (`login [2fa|touch|off]`): `pam_u2f` in `/etc/pam.d/system-local-login`, which
covers the tty login and swaylock; i3lock gets its own line if it doesn't go through
`login`. `2fa` (default): password, then touch. `touch`: touch alone is enough (the
password still works without the key). SSH is not affected. The keys of each user are in
`/etc/u2f_mappings` (root-owned). Test on another tty (Ctrl+Alt+F3) before logging out.

**sudo** (`sudo [touch|2fa|off]`): touch instead of the password; the script tests
`sudo` right away and puts the old file back if it fails.

**Undo**: `yubikey-setup login off`, `yubikey-setup sudo off`, `yubikey-setup undo disk`
(removes the key slots; the passphrase stays). Old files: `/root/yubikey-backup/`.

**Locked out of login?** Boot, unlock the disk with the passphrase, at the systemd-boot
menu press `e` and add `systemd.unit=rescue.target`, log in as root and run
`sed -i '/pam_u2f/d' /etc/pam.d/system-local-login /etc/pam.d/sudo`.

## macOS Ventura (and newer)

```sh
brew install ykman          # (the dotfiles' Brewfile has it)
yubikey-setup-mac setup     # PIV PIN/PUK, keys + certificates in 9a / 9d, pairing
yubikey-setup-mac status
yubikey-setup-mac lock-on-remove on   # optional: lock when the key is pulled out
```

macOS has PIV smart card support built in: the YubiKey gets a key and a certificate in
slot 9a (authentication) and 9d (key management, for FileVault and the keychain), and
`sc_auth pair` links them to your account. Then the login window and the lock screen
ask for the PIV PIN when the key is in; the password still works.

- **FileVault**: on Apple silicon the FileVault screen at boot takes the key's PIN too.
  On Intel Macs (T2) FileVault has no smart card support: password at boot, key after.
- **Second Mac**: plug the same key in there and run `yubikey-setup-mac pair`.
- **Second key**: run `setup` with it too; each key is paired separately.
- **Undo**: `yubikey-setup-mac unpair`.
- Smart card only (password disabled) is possible with a configuration profile
  (`enforceSmartCard`); not done here on purpose: one lost key would lock the Mac.

## Windows 11

Run `windows\yubikey-setup.ps1` (from this folder) in an administrator PowerShell
(`Set-ExecutionPolicy -Scope Process Bypass` first). Without options it shows your account
type, BitLocker and TPM, and the next steps.

1. **FIDO2 PIN**: `.\yubikey-setup.ps1 -Tools` (installs Yubico Authenticator), or
   Settings → Accounts → Sign-in options → Security key → Manage.
2. **Microsoft account**: account.microsoft.com → Security → Advanced security options →
   Add a new way to sign in → *Face, fingerprint, PIN, or security key*. The YubiKey then
   signs you in to the account (web, Outlook, Xbox …), by USB-C or NFC. Windows sign-in
   itself stays on Windows Hello (PIN / fingerprint): a YubiKey can sign in to Windows
   only with a work account in Entra ID.
3. **Disk**: `.\yubikey-setup.ps1 -BitLockerPin`. BitLocker can't use a YubiKey before
   Windows starts, so this sets up the strong alternative: TPM + startup PIN, and shows
   the recovery key to save on a USB stick or paper (not on that PC). Windows Home has
   only Device encryption, without a PIN.
4. **Local account sign-in with the key**: first `.\yubikey-setup.ps1 -RecoveryAdmin` (a
   spare admin account), then `-LoginTool` opens Yubico Login for Windows. Configure it
   with two keys and keep its recovery code: after that the password alone no longer
   signs in to that account. x86 PCs and local accounts only.

## Everyday use

- Arch boot: PIN + touch. sudo: touch. Lock screen: password, then touch (2fa).
- macOS: PIN at the login window and lock screen while the key is in.
- Lost a key: remove it before someone finds it. Arch: `systemd-cryptenroll <disk>
  --wipe-slot=fido2` and re-add the remaining key, edit its line out of
  `/etc/u2f_mappings`. macOS: `yubikey-setup-mac unpair` and pair the spare one.
  Microsoft account: remove the security key on account.microsoft.com.

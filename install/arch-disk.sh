#!/bin/bash
#
# arch-disk.sh: step 1 of an encrypted Arch install, on the Arch ISO before pacstrap.
# Wipes ONE disk and makes:
#   partition 1   1 GiB  EFI (FAT32, not encrypted)  -> /mnt/boot  (systemd-boot, kernels)
#   partition 2   rest   LUKS2 (argon2id), your passphrase
#                        └ btrfs (subvolumes @ @home @log @pkg @snapshots, zstd)
#                          or ext4                    -> /mnt
# and, if you want, adds a YubiKey (FIDO2) as a second way to unlock it, next to the
# passphrase. Then: pacstrap, arch-bootstrap.sh (it finds all of this by itself).
#
#   bash arch-disk.sh                  asks for everything
#   bash arch-disk.sh /dev/nvme0n1     that disk
# Options: --fs btrfs|ext4 (btrfs), --yubikey / --no-yubikey (ask), --name NAME (cryptroot)
#
# Guide: yubikey/README.md in the dotfiles ("A new encrypted Arch install").

set -euo pipefail

FS="" YUBI="" NAME=cryptroot DISK=""
c_y=$'\e[1;33m' c_r=$'\e[1;31m' c_g=$'\e[1;32m' c_b=$'\e[1;34m' c_0=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$c_b" "$*" "$c_0"; }
ok() { printf '%s ok%s  %s\n' "$c_g" "$c_0" "$*"; }
die() { printf '%serror:%s %s\n' "$c_r" "$c_0" "$*" >&2; exit 1; }
usage() { sed -n '3,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while (($#)); do
	case $1 in
	--fs) FS=${2:-}; shift ;;
	--yubikey) YUBI=1 ;;
	--no-yubikey) YUBI=0 ;;
	--name) NAME=${2:-}; shift ;;
	-h | --help) usage ;;
	/dev/*) DISK=$1 ;;
	*) usage 2 ;;
	esac
	shift
done

[[ $EUID -eq 0 ]] || die "run it as root (on the Arch ISO you are)"
[[ -d /sys/firmware/efi/efivars ]] || die "boot the ISO in UEFI mode (this layout is for UEFI + systemd-boot)"
for t in sgdisk cryptsetup mkfs.fat wipefs partprobe; do command -v "$t" >/dev/null || die "missing $t"; done
mountpoint -q /mnt && die "/mnt is in use: umount -R /mnt (and cryptsetup close $NAME) first"

# ---------------------------------------------------------------- questions
step "Disk"
lsblk -dpno NAME,SIZE,MODEL,TRAN | grep -Ev 'loop|sr[0-9]|zram' | sed 's/^/    /'
if [[ -z $DISK ]]; then
	read -r -p "Disk to wipe and encrypt (e.g. /dev/nvme0n1): " DISK
fi
[[ -b $DISK && $(lsblk -dno TYPE "$DISK") == disk ]] || die "$DISK is not a disk"
iso=$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null || true)
[[ -n $iso && $iso == "$DISK"* ]] && die "$DISK is the USB stick you booted from"

if [[ -z $FS ]]; then
	read -r -p "Filesystem: btrfs (snapshots, compression) or ext4 [btrfs]: " FS
	FS=${FS:-btrfs}
fi
[[ $FS == btrfs || $FS == ext4 ]] || die "--fs btrfs or ext4"

if [[ -z $YUBI ]]; then
	read -r -p "Add a YubiKey now as a second way to unlock the disk? [y/N] " a
	[[ $a == [yY]* ]] && YUBI=1 || YUBI=0
fi

# partition names: /dev/nvme0n1 -> /dev/nvme0n1p1, /dev/sda -> /dev/sda1
p=""
[[ $DISK =~ [0-9]$ ]] && p=p
EFI=${DISK}${p}1 LUKS=${DISK}${p}2

ssd=0
[[ $(cat "/sys/block/$(basename "$DISK")/queue/rotational" 2>/dev/null) == 0 ]] && ssd=1

echo
lsblk -po NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$DISK" | sed 's/^/    /'
echo
echo "${c_y}EVERYTHING on $DISK will be deleted.${c_0} New: $EFI (EFI, 1 GiB), $LUKS (LUKS2, $FS)$( ((YUBI)) && echo ', + YubiKey')"
read -r -p "Type the disk name again to go on ($DISK): " again
[[ $again == "$DISK" ]] || die "stopped, nothing changed"

# ---------------------------------------------------------------- partitions
step "Partitions"
swapoff -a 2>/dev/null || true
wipefs -af "$DISK" >/dev/null
sgdisk --zap-all "$DISK" >/dev/null
sgdisk -n1:0:+1G -t1:ef00 -c1:EFI -n2:0:0 -t2:8309 -c2:cryptsystem "$DISK" >/dev/null
partprobe "$DISK"
udevadm settle
for _ in 1 2 3 4 5; do [[ -b $LUKS ]] && break; sleep 1; done
[[ -b $EFI && -b $LUKS ]] || die "partitions $EFI / $LUKS did not appear"
ok "$EFI EFI, $LUKS Linux LUKS"

# ---------------------------------------------------------------- LUKS2
step "Encryption (LUKS2)"
echo "Choose the disk passphrase. It stays valid even with a YubiKey: write it down"
echo "and keep it safe. The keyboard layout at boot is US until the system sets yours."
cryptsetup luksFormat --type luks2 --pbkdf argon2id --label cryptsystem --verify-passphrase "$LUKS"
open_opts=()
# SSD: TRIM through the encryption and no extra work queues; saved in the LUKS header
((ssd)) && open_opts=(--allow-discards --perf-no_read_workqueue --perf-no_write_workqueue --persistent)
echo "Unlock it once now (the same passphrase):"
cryptsetup open "${open_opts[@]}" "$LUKS" "$NAME"
ok "/dev/mapper/$NAME open$( ((ssd)) && echo ' (SSD: discard on)')"

if ((YUBI)); then
	step "YubiKey (FIDO2)"
	# FIDO2 support and ykman for the live system (in RAM; the new system gets its own)
	pacman -Sy --noconfirm --needed libfido2 yubikey-manager >/dev/null ||
		echo "  (could not install libfido2 / yubikey-manager: network?)"
	if ! systemd-cryptenroll --fido2-device=list 2>/dev/null | grep -q /dev/; then
		echo "  no FIDO2 key found"
		read -r -p "Plug in the YubiKey and press Enter (or type skip): " a
		[[ $a == skip ]] && YUBI=0
	fi
fi
if ((YUBI)); then
	if ykman fido info 2>/dev/null | grep -qiE 'PIN.*not set'; then
		echo "The key has no FIDO2 PIN yet (needed: key + PIN unlock the disk). Set it now:"
		ykman fido access change-pin || true
	fi
	echo "Now: the disk passphrase, then the key's PIN, then touch the key."
	if systemd-cryptenroll "$LUKS" --fido2-device=auto --fido2-with-client-pin=yes --fido2-with-user-presence=yes; then
		ok "YubiKey added; the passphrase stays. Second key later: yubikey-setup add-key"
	else
		# not fatal: the disk works with the passphrase; the key can be added later
		printf '%swarning:%s the key was not added. Going on without it; after the install: yubikey-setup disk\n' "$c_y" "$c_0"
		YUBI=0
	fi
fi

# ---------------------------------------------------------------- filesystems
step "Filesystems ($FS)"
mkfs.fat -F32 -n EFI "$EFI" >/dev/null
if [[ $FS == btrfs ]]; then
	mkfs.btrfs -q -f -L arch "/dev/mapper/$NAME"
	mount "/dev/mapper/$NAME" /mnt
	for sv in @ @home @log @pkg @snapshots; do btrfs -q subvolume create "/mnt/$sv"; done
	umount /mnt
	o=noatime,compress=zstd
	((ssd)) && o+=,ssd
	mount -o "$o,subvol=@" "/dev/mapper/$NAME" /mnt
	mount --mkdir -o "$o,subvol=@home" "/dev/mapper/$NAME" /mnt/home
	mount --mkdir -o "$o,subvol=@log" "/dev/mapper/$NAME" /mnt/var/log
	mount --mkdir -o "$o,subvol=@pkg" "/dev/mapper/$NAME" /mnt/var/cache/pacman/pkg
	mount --mkdir -o "$o,subvol=@snapshots" "/dev/mapper/$NAME" /mnt/.snapshots
else
	mkfs.ext4 -q -F -L arch "/dev/mapper/$NAME"
	mount -o noatime "/dev/mapper/$NAME" /mnt
fi
# fmask/dmask: the boot loader's random seed must not be readable by everyone
mount --mkdir -o fmask=0077,dmask=0077 "$EFI" /mnt/boot
ok "mounted:"
findmnt -R /mnt -o TARGET,SOURCE,FSTYPE | sed 's/^/    /'

step "Next"
cat <<EOF
    pacstrap -K /mnt base linux linux-firmware
    curl -LO https://raw.githubusercontent.com/darktime78/dotfiles/master/install/arch-bootstrap.sh
    bash arch-bootstrap.sh

arch-bootstrap.sh sees the encryption$( ((YUBI)) && echo ' and the YubiKey') and sets up the boot for it.
At every boot: $( ((YUBI)) && echo 'key in -> its PIN + touch; no key -> the passphrase.' || echo 'the passphrase. Add a YubiKey later: yubikey-setup pin && yubikey-setup disk')
Keep a copy of the LUKS header (cryptsetup luksHeaderBackup $LUKS --header-backup-file ...)
on a USB stick: a damaged header means the data is gone even with the passphrase.
EOF

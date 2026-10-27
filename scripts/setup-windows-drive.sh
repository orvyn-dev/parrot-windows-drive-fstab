#!/usr/bin/env bash
# Set up safe automatic NTFS mounting on Parrot OS after a reinstall.
set -Eeuo pipefail

MOUNT_POINT="/mnt/windows-drive"
DEFAULT_UUID="FE9A3ADD9A3A925F"
FSTAB="/etc/fstab"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

if (( EUID != 0 )); then
  die "Run this as your normal account with sudo: sudo bash scripts/setup-windows-drive.sh [WINDOWS_UUID]"
fi
if [[ -z "${SUDO_UID:-}" || -z "${SUDO_GID:-}" ]]; then
  die "Run this through sudo from your regular Linux account; SUDO_UID/SUDO_GID must be available."
fi
if (( $# > 1 )); then
  die "Usage: sudo bash scripts/setup-windows-drive.sh [WINDOWS_UUID]"
fi

UUID="${1:-$DEFAULT_UUID}"
DEVICE="$(blkid -U "$UUID" 2>/dev/null || true)"
if [[ -z "$DEVICE" ]]; then
  lsblk -f
  die "Windows volume with UUID $UUID not found. Find its current UUID using lsblk -f."
fi
TYPE="$(blkid -o value -s TYPE "$DEVICE")"
[[ "$TYPE" == "ntfs" ]] || die "$DEVICE is $TYPE, not NTFS. Refusing to edit fstab."

ENTRY="UUID=$UUID $MOUNT_POINT ntfs-3g uid=$SUDO_UID,gid=$SUDO_GID,umask=022,nofail,x-gvfs-show 0 0"

printf '\nDevice:      %s\nFilesystem:  %s\nMount point: %s\nOwner ID:    %s:%s\n' \
  "$DEVICE" "$TYPE" "$MOUNT_POINT" "$SUDO_UID" "$SUDO_GID"
printf '\nProposed /etc/fstab line:\n%s\n\n' "$ENTRY"

if findmnt -rn --mountpoint "$MOUNT_POINT" >/dev/null; then
  SOURCE="$(findmnt -rn -o SOURCE --mountpoint "$MOUNT_POINT")"
  [[ "$SOURCE" == "$DEVICE" ]] || die "$MOUNT_POINT is mounted from $SOURCE, not $DEVICE."
fi

read -r -p "Apply this configuration? [y/N] " ANSWER
[[ "$ANSWER" == y || "$ANSWER" == Y ]] || { echo 'Cancelled; no changes made.'; exit 0; }

if ! command -v ntfs-3g >/dev/null 2>&1; then
  apt-get update
  apt-get install -y ntfs-3g
fi

mkdir -p "$MOUNT_POINT"
if grep -Fqx -- "$ENTRY" "$FSTAB"; then
  echo 'The exact fstab entry already exists; no new line needed.'
else
  if awk -v id="UUID=$UUID" -v target="$MOUNT_POINT" \
    '$0 !~ /^[[:space:]]*#/ && ($1 == id || $2 == target) { found=1 } END { exit !found }' "$FSTAB"; then
    die "A conflicting fstab entry exists for the UUID or mountpoint. Review /etc/fstab manually."
  fi
  BACKUP="$FSTAB.backup.$(date +%Y%m%d-%H%M%S)"
  cp -a "$FSTAB" "$BACKUP"
  printf '\n# Windows NTFS drive - added by setup-windows-drive.sh\n%s\n' "$ENTRY" >> "$FSTAB"
  printf 'Backup: %s\n' "$BACKUP"
fi

systemctl daemon-reload
findmnt --verify --verbose
if ! findmnt -rn --mountpoint "$MOUNT_POINT" >/dev/null; then
  mount "$MOUNT_POINT"
fi
printf '\nMounted Windows partition:\n'
findmnt --mountpoint "$MOUNT_POINT"
printf '\nAfter reboot, verify auto-mount with: findmnt %s\n' "$MOUNT_POINT"

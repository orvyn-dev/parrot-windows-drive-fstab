# Parrot OS — Windows NTFS Auto-Mount Setup

Restore access to your Windows partition after reinstalling Parrot OS on a Windows/Linux dual-boot laptop. This repository records a successfully tested configuration and provides an interactive setup script.

## Recorded working configuration — 27 October 2026

| Item | Value |
|---|---|
| Linux | Parrot OS |
| Windows | Windows 11 |
| Laptop | Dell Latitude 5300 |
| Windows partition | `/dev/nvme0n1p3` |
| Windows NTFS UUID | `FE9A3ADD9A3A925F` |
| Mount directory | `/mnt/windows-drive` |
| Driver | `ntfs-3g` (appears as `fuseblk`) |
| Linux UID/GID | `1000:1000` (the script detects these automatically) |
| Mount options | `uid=1000,gid=1000,umask=022,nofail,x-gvfs-show` |

The Windows partition was mounted successfully, and the normal Linux user successfully created, read and deleted a test file.

**Important:** Linux root and swap UUIDs may change after a fresh installation. **Do not restore an old complete `/etc/fstab` file.** Only add the Windows entry. Verify the Windows volume UUID each time; the UUID above is a recorded value, not a universal constant.

## Quick restore after reinstalling Parrot OS

1. In Windows, disable **Fast Startup** and fully shut down. Do not access hibernated Windows filesystems for writing from Linux.
2. In Parrot OS, identify the **main Windows NTFS partition**, not the smaller NTFS recovery partition:

   ```bash
   lsblk -f
   ```

3. Clone this repository, review the script, and run it:

   ```bash
   sudo apt update
   sudo apt install -y git
   git clone https://github.com/orvyn-dev/parrot-windows-drive-fstab.git
   cd parrot-windows-drive-fstab
   less scripts/setup-windows-drive.sh
   sudo bash scripts/setup-windows-drive.sh
   ```

   The script verifies the selected device is NTFS, detects the current UID/GID, displays its proposed fstab entry, asks for confirmation, installs `ntfs-3g` if missing, backs up fstab, avoids duplicate entries, reloads systemd, verifies the configuration and mounts the drive.

   If the Windows UUID has changed, provide the new UUID:

   ```bash
   sudo bash scripts/setup-windows-drive.sh YOUR_NEW_WINDOWS_UUID
   ```

4. Verify that it worked:

   ```bash
   findmnt /mnt/windows-drive
   ls /mnt/windows-drive
   xdg-open /mnt/windows-drive
   ```

5. Reboot, **without manually mounting** afterwards, and run `findmnt /mnt/windows-drive` again to confirm automatic mounting at startup.

## Manual setup

If you prefer not to run the script:

```bash
sudo apt update
sudo apt install -y ntfs-3g
sudo mkdir -p /mnt/windows-drive
sudo cp -a /etc/fstab /etc/fstab.backup
sudo nano /etc/fstab
```

Append **one** Windows entry at the bottom, adjusting the UUID and numeric user/group IDs as appropriate (use `lsblk -f`, `id -u`, and `id -g` to check):

```fstab
# Windows Drive
UUID=FE9A3ADD9A3A925F /mnt/windows-drive ntfs-3g uid=1000,gid=1000,umask=022,nofail,x-gvfs-show 0 0
```

Keep the current installation's other entries for `/`, `/boot/efi`, swap, and `/tmp` unchanged.

```bash
sudo systemctl daemon-reload
sudo findmnt --verify --verbose
sudo mount /mnt/windows-drive
findmnt /mnt/windows-drive
```

**About verification warnings:** `findmnt --verify` can report "ntfs-3g seems unsupported by the current kernel" and "ntfs-3g does not match with on-disk ntfs". These may occur because `ntfs-3g` is a userspace FUSE driver; they are not by themselves proof of failure. A successful `mount` followed by `findmnt` confirms the actual mount.

## Read/write check

Only when the Windows volume has been safely mounted for writing:

```bash
touch /mnt/windows-drive/Parrot-Mount-Test.txt
ls -l /mnt/windows-drive/Parrot-Mount-Test.txt
rm /mnt/windows-drive/Parrot-Mount-Test.txt
```

On the recorded installation, creating and deleting the file succeeded without `sudo`.

An existing `hiberfil.sys` is normal and is not itself proof of active hibernation. If mounting warns of an unsafe or hibernated Windows state, **do not force a writable mount or remove `hiberfil.sys`**. Boot Windows and shut it down fully instead.

## Repository files

- [`scripts/setup-windows-drive.sh`](scripts/setup-windows-drive.sh) — interactive auto-mount setup and validation
- `README.md` — quick restore, manual instructions, testing and safety

This project intentionally stores a **configuration recipe**, not a snapshot of your machine's entire `/etc/fstab`.

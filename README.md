# nvimos

A minimal, terminal-only Arch Linux live/install ISO. No display server, no
desktop environment — just a TTY, nvim, and config files. Wi-Fi and
Bluetooth work out of the box.

## What's in it

- Boots straight to an autologged-in root shell on tty1 (BIOS via syslinux,
  UEFI via systemd-boot).
- `nvim` installed and set as `$EDITOR`/`$VISUAL` system-wide.
- Wi-Fi via NetworkManager — run `nmtui` or
  `nmcli device wifi connect <SSID> --ask`.
- Bluetooth via `bluez`/`bluez-utils` — run `bluetoothctl`.
- `sshd` enabled, so you can SSH in instead of using the local console.
- Arch install tooling kept (`arch-install-scripts`, `grub`, `parted`,
  `dosfstools`, `e2fsprogs`, `efibootmgr`) so it can install itself to disk
  the normal Arch way, then nvim is there to edit `fstab`, `pacman.conf`,
  etc. during the install.
- Everything from the stock `releng` profile that wasn't needed for this
  (rescue/recovery tools, VM guest agents, cloud-init, accessibility/audio,
  zsh, GUI bits) was stripped out — see `profile/packages.x86_64`.

## Setup commands (host side, one-time)

```sh
sudo apt install -y docker.io
sudo usermod -aG docker $USER   # then re-login, or use sudo for docker
```

## Building the ISO

```sh
./build.sh
```

This runs `mkarchiso` inside a privileged `archlinux:base-devel` Docker
container (archiso needs pacman + chroot/loop mounts that don't exist on
Ubuntu directly). Output lands in `./out/nvimos-<date>-x86_64.iso`.
Needs ~3 GB free disk during the build (cleaned up automatically after).

## Testing

```sh
qemu-system-x86_64 -m 2048 -cdrom out/nvimos-*.iso -boot d
```

Or flash to USB with `dd` / Ventoy / Rufus and boot real hardware.

## Customizing further

- `profile/packages.x86_64` — package list.
- `profile/airootfs/` — overlay filesystem (root's `.bashrc`, motd,
  enabled systemd services under `etc/systemd/system/*.wants/`, etc.).
- `profile/profiledef.sh` — ISO metadata (name, label, boot modes).

After editing, just re-run `./build.sh`.

## install-image/ — installed-disk variant (lower RAM floor)

The live ISO above needs ~512MB RAM to boot, because archiso's initramfs
has to support booting on *any* PC (broad hardware detection = bigger
initramfs = more RAM to decompress it). `install-image/build-disk.sh`
instead builds a real installed-to-disk image (pacstrap + arch-chroot,
GRUB BIOS, ext4) using mkinitcpio's `autodetect` hook, which prunes the
initramfs down to just what's needed. That alone drops the boot floor to
roughly 160–192MB.

```sh
cd install-image
./build-disk.sh
qemu-system-x86_64 -m 256 -drive file=disk.img,format=raw
```

Note: `autodetect` only includes kernel modules present on the *build*
machine, not the target — since this builds inside a generic Docker
container, `chroot-setup.sh` explicitly adds common storage-controller
modules (`ahci`, `ata_piix`, `virtio_blk`, `nvme`, etc.) via `MODULES=` in
`mkinitcpio.conf` so it still boots on real hardware or other VM backends.
`disk.img` itself isn't committed (3GB raw image) — rebuild it with
`./build-disk.sh`.

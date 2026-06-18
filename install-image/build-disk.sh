#!/usr/bin/env bash
# Builds an installed-to-disk nvimos image (as opposed to the live ISO),
# so it uses a normal hardware-specific initramfs (autodetect hook) instead
# of archiso's universal-hardware-support initramfs. Partitioning/mounting
# is done on the host (real udev, so loop partition nodes actually appear);
# only pacstrap/arch-chroot run inside a privileged Arch container, since
# those need real Arch tooling.
set -euxo pipefail
cd "$(dirname "$0")"

MNT="$PWD/mnt-root"
sudo umount -R "$MNT" 2>/dev/null || true
sudo rmdir "$MNT" 2>/dev/null || true

# Clean up any loop device still attached to this disk.img from a previous run.
DISK_INODE=$(stat -c %i "$PWD/disk.img")
for dev in $(sudo losetup -a | cut -d: -f1); do
  if sudo losetup -a | grep "^${dev}:" | grep -q "\]:${DISK_INODE} "; then
    sudo losetup -d "$dev" || true
  fi
done

LOOPDEV=$(sudo losetup -P -f --show "$PWD/disk.img")
cleanup() { sudo umount -R "$MNT" 2>/dev/null || true; sudo losetup -d "$LOOPDEV" 2>/dev/null || true; }
trap cleanup EXIT

sudo parted -s "$LOOPDEV" mklabel msdos
sudo parted -s "$LOOPDEV" mkpart primary ext4 1MiB 100%
sudo parted -s "$LOOPDEV" set 1 boot on
sudo partx -u "$LOOPDEV"
sleep 1
PART="${LOOPDEV}p1"
sudo mkfs.ext4 -F "$PART"

mkdir -p "$MNT"
sudo mount "$PART" "$MNT"

sudo docker run --rm --privileged \
  -v "$MNT":/mnt/root \
  -v "$PWD/chroot-setup.sh":/chroot-setup.sh:ro \
  --device="${LOOPDEV}" \
  -e LOOPDEV="${LOOPDEV}" \
  archlinux:base-devel bash -c '
set -euxo pipefail
pacman -Sy --noconfirm archlinux-keyring >/var/log/build.log 2>&1
pacman -S --noconfirm arch-install-scripts grub >>/var/log/build.log 2>&1

pacstrap -K /mnt/root \
  amd-ucode base bluez bluez-utils dosfstools e2fsprogs grub \
  intel-ucode iw linux linux-firmware mkinitcpio neovim networkmanager \
  ntfs-3g openssh parted sudo terminus-font wireless-regdb wireless_tools \
  wpa_supplicant

genfstab -U /mnt/root >> /mnt/root/etc/fstab

echo "nvimos" > /mnt/root/etc/hostname
ln -sf /usr/share/zoneinfo/UTC /mnt/root/etc/localtime
echo "LANG=en_US.UTF-8" > /mnt/root/etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /mnt/root/etc/locale.gen
printf "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 nvimos.localdomain nvimos\n" >> /mnt/root/etc/hosts

mkdir -p /mnt/root/etc/modprobe.d
cat > /mnt/root/etc/modprobe.d/blacklist-gpu.conf <<EOF
blacklist nouveau
blacklist amdgpu
blacklist radeon
blacklist i915
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_uvm
EOF

mkdir -p /mnt/root/etc/profile.d
cat > /mnt/root/etc/profile.d/nvim-editor.sh <<EOF
export EDITOR=nvim
export VISUAL=nvim
EOF

cat > /mnt/root/etc/motd <<EOF
nvimos - minimal terminal-only Arch Linux (installed)

Wi-Fi:      nmtui          (or nmcli device wifi connect <SSID> --ask)
Bluetooth:  bluetoothctl
Editor:     nvim is the default \$EDITOR
EOF

mkdir -p /mnt/root/root
cat > /mnt/root/root/.bashrc <<"EOF"
export EDITOR=nvim
export VISUAL=nvim
alias vi=nvim
alias vim=nvim
alias ls="ls --color=auto"
PS1="\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ "
EOF
cat > /mnt/root/root/.bash_profile <<"EOF"
[[ -f ~/.bashrc ]] && . ~/.bashrc
EOF

cp /chroot-setup.sh /mnt/root/chroot-setup.sh
chmod +x /mnt/root/chroot-setup.sh
arch-chroot /mnt/root /chroot-setup.sh "$LOOPDEV"
rm /mnt/root/chroot-setup.sh
echo DONE
'

echo BUILD COMPLETE

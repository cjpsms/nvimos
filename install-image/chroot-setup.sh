#!/usr/bin/env bash
set -euxo pipefail

LOOPDEV="$1"

locale-gen
passwd -d root
chsh -s /usr/bin/bash root

sed -i "s/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf keyboard keymap consolefont block filesystems fsck)/" /etc/mkinitcpio.conf
# autodetect only includes modules present on the *build* machine (this
# container), not the target machine, so explicitly include common storage
# controllers (MODULES= is always included regardless of autodetect).
sed -i "s/^MODULES=.*/MODULES=(ahci ata_piix sd_mod virtio_blk virtio_pci virtio_scsi nvme)/" /etc/mkinitcpio.conf
mkinitcpio -P

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOC'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --noreset --noclear --autologin root - ${TERM}
EOC

systemctl enable NetworkManager bluetooth sshd

grub-install --target=i386-pc --boot-directory=/boot "$LOOPDEV"
grub-mkconfig -o /boot/grub/grub.cfg

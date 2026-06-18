#!/usr/bin/env bash
# Builds the nvimos ISO from ./profile using a privileged Arch Linux Docker
# container (archiso's mkarchiso needs pacman + chroot/loop mounts, which
# aren't available on this Ubuntu host directly).
set -e
cd "$(dirname "$0")"
mkdir -p out work
sudo docker run --rm --privileged \
  -v "$PWD/profile":/profile:ro \
  -v "$PWD/out":/out \
  -v "$PWD/work":/work \
  archlinux:base-devel bash -c "
set -e
pacman -Sy --noconfirm archlinux-keyring >/var/log/build.log 2>&1
pacman -S --noconfirm archiso dosfstools squashfs-tools libisoburn >>/var/log/build.log 2>&1
cp -r /profile /tmp/profile
chmod -R u+w /tmp/profile
mkarchiso -v -w /work -o /out /tmp/profile
"
sudo chown -R "$USER:$USER" out work
sudo rm -rf work
echo "ISO built in ./out/"

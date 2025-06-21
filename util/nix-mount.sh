#! /bin/bash
DISK=/dev/nvme0n1p
BTRFSDSK=7
BOOTDISK=4


cryptsetup open "$DISK""$BTRFSDSK" enc
ENCDISK=/dev/mapper/enc

mount -o subvol=root,compress=zstd,noatime "$ENCDISK" /mnt

mkdir /mnt/home
mount -o subvol=home,compress=zstd,noatime "$ENCDISK" /mnt/home

mkdir /mnt/nix
mount -o subvol=nix,compress=zstd,noatime "$ENCDISK" /mnt/nix

mkdir /mnt/persist
mount -o subvol=persist,compress=zstd,noatime "$ENCDISK" /mnt/persist

mkdir -p /mnt/var/log
mount -o subvol=log,compress=zstd,noatime "$ENCDISK" /mnt/var/log

mkdir /mnt/boot
mount "$DISK""$BOOTDISK" /mnt/boot

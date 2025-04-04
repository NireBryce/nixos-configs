#!/bin/env bash
set -euo pipefail

DISK=/dev/nvme0n1

_BOOT="${DISK}p1"
    parted "${DISK}" -- mklabel gpt
    parted "${DISK}" -- mkpart ESP fat32 1MiB 1GiB
    parted "${DISK}" -- set 1 boot on
    mkfs.vfat "${_BOOT}"

_SWAP="${DISK}p2"
    parted "${_SWAP}" -- mkpart Swap linux-swap 1GiB 21GiB
    mkswap -L Swap "${_SWAP}"
    swapon "${_SWAP}"

_BTRFS="${DISK}p3" 
    cryptsetup --verify-passphrase -v luksFormat "${_BTRFS}"
    cryptsetup open "${_BTRFS}" enc
    mkfs.btrfs /dev/mapper/enc

_LUKS=/dev/mapper/enc
    cryptsetup open "${_BTRFS}" enc
    btrfs subvolume create /mnt/root
    btrfs subvolume create /mnt/home
    btrfs subvolume create /mnt/nix
    btrfs subvolume create /mnt/persist
    btrfs subvolume create /mnt/log
    # snapshot
    btrfs subvolume sna[shot -r /mnt/root
    umount /mnt

mount -o subvol=root,compress=zstd,noatime          \
      "${_LUKS}"                                    \
      /mnt
    
    mkdir /mnt/home
    mount -o subvol=home,compress=zstd              \
      "${_LUKS}"                                    \
      /mnt/home

    mkdir /mnt/nix
    mount -o subvol=nix,compress=zstd,noatime       \
      "${_LUKS}"                                    \
      /mnt/nix

    mkdir /mnt/persist
    mount -o subvol=persist,compress=zstd,noatime   \
      "${_LUKS}"                                    \
      /mnt/persist

    mkdir -p /mnt/var/log
    mount -o subvol=log,compress=zstd,noatime       \
      "${_LUKS}"                                    \
      /mnt/var/log

    # don't forget this!
    mkdir /mnt/boot
    mount "${_BOOT}" /mnt/boot


nixos-generate-config --root /mnt


# TODO: sep into functions, cconsider using a "do nothing script" for stepwise
# TODO: figure out how to do disko while preserving windows partition




# after:
# nixos-install
# reboot

read -p -r -s "Enter user password: " _PASSWORD
sudo mkpasswd -m sha-512 "${_PASSWORD}" > /mnt/persist/passwords/elly
ssh-keygen -t ed25519 -C "elly@nire-avarice"


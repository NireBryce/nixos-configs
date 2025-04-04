#!/bin/env bash
set -euo pipefail; shopt -s inherit_set


sudo nixos-rebuild boot

cryptsetup open /dev/nvme0n1p7 enc
sudo mkdir /mnt; 
sudo mount -o subvol=/ /dev/vmapper/enc /mnt;
./fs-diff.sh





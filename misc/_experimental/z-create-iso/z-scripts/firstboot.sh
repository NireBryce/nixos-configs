#!/bin/env bash
set -euo pipefail; shopt -s inherit_set


sudo mkdir /mnt; 
sudo mount -o subvol=/ /dev/vda3 /mnt;
./fs-diff.sh




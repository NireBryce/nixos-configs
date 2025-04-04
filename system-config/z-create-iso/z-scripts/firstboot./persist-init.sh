#!/bin/env bash
set -euo pipefail


sudo mkdir /persist/etc

sudo cp -r {,/persist}/etc/nixos
sudo cp {,/persist}/etc/machine-id

sudo mkdir /persist/etc/ssh

sudo cp {,/persist}/etc/ssh/ssh_host_ed25519_key
sudo cp {,/persist}/etc/ssh/ssh_host_ed25519_key.pub
sudo cp {,/persist}/etc/ssh/ssh_host_rsa_key
sudo cp {,/persist}/etc/ssh/ssh_host_rsa_key.pub


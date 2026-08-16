#!/usr/bin/env bash
# Build the nire-installer live-USB image and print where it landed and how
# to write it.
#
#     build-liveusb.sh <flake-dir>
#
# Does not write to any device itself. `dd`ing the wrong target is
# unrecoverable and this script has no way to know which /dev/sdX on the
# machine running it is the USB stick and which is its own disk -- it builds
# the image and prints the exact command; running that command against a
# confirmed device is a decision for whoever is looking at `lsblk`.
set -euo pipefail

flake=${1:?usage: build-liveusb.sh <flake-dir>}

# Wifi for installer-autoinstall-testbed.nix's unattended install --
# read here, at build time, and passed through as env vars rather than ever
# written to a file in this repo. `--impure` below is what actually lets
# that module's builtins.getEnv see them; without it (any plain `nix eval`,
# `nix flake check`, `just modules`) they're silently "" and nothing about
# this feature activates -- see that file's own header.
#
# Skippable: empty SSID leaves wifi exactly as installer-configuration.nix
# already has it (NetworkManager on, nmtui by hand, ethernet always works
# with no credentials needed either way).
if [ -z "${NIRE_INSTALLER_WIFI_SSID:-}" ]; then
    read -r -p "Wifi SSID for unattended autoinstall (blank to skip, connect by hand instead): " NIRE_INSTALLER_WIFI_SSID
fi
if [ -n "$NIRE_INSTALLER_WIFI_SSID" ] && [ -z "${NIRE_INSTALLER_WIFI_PASSWORD:-}" ]; then
    read -r -s -p "Wifi password for '$NIRE_INSTALLER_WIFI_SSID': " NIRE_INSTALLER_WIFI_PASSWORD
    echo >&2
fi
export NIRE_INSTALLER_WIFI_SSID NIRE_INSTALLER_WIFI_PASSWORD

if [ -n "$NIRE_INSTALLER_WIFI_SSID" ]; then
    echo "==> wifi credentials for '$NIRE_INSTALLER_WIFI_SSID' will be baked into this image in plaintext (Nix store, no other way to auto-connect unattended) -- treat the built .iso as sensitive" >&2
fi

echo "==> building nire-installer (first build pulls down a full ISO closure, expect it to take a while)" >&2
out=$(nix build --impure "${flake}#liveusb-testbed-installer" --print-out-paths --no-link)
iso=$(find "$out/iso" -maxdepth 1 -name '*.iso' -print -quit)

if [ -z "$iso" ]; then
    echo "build-liveusb.sh: built $out but found no *.iso under iso/ -- isoImage's layout may have changed upstream" >&2
    exit 1
fi

echo
echo "==> built: $iso"
echo
echo "Find the USB stick's device -- the whole disk, not a partition -- with:"
echo "    lsblk"
echo
echo "Then, with that device confirmed and nothing else attached you'd mind losing:"
echo "    sudo dd if=$iso of=/dev/sdX bs=4M status=progress conv=fsync"
echo
echo "This overwrites everything on /dev/sdX. Double-check the device before running it."
echo
echo "On boot, autoinstall-testbed.service runs unattended once it finds the"
echo "expected partitions and gets network -- watch it (e.g. over SSH) with:"
echo "    journalctl -u autoinstall-testbed -f"
echo "A 10s window at the start allows 'systemctl stop autoinstall-testbed' to abort."

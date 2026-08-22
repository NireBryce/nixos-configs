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

# The flake attr Calamares' patched `nixos` job installs -- required, not
# skippable: there is no sensible default target to install unattended, and
# an empty one just means `nixos-install --flake path:...#` at runtime,
# which fails opaquely on the machine being installed instead of here.
if [ -z "${NIRE_INSTALLER_TARGET_HOST:-}" ]; then
    read -r -p "Target flake attr to install (e.g. nire-testbed): " NIRE_INSTALLER_TARGET_HOST
fi
: "${NIRE_INSTALLER_TARGET_HOST:?build-liveusb.sh: a target host is required}"
export NIRE_INSTALLER_TARGET_HOST

# Unattended autoinstall for installer-autoinstall.nix -- read here, at build
# time, and passed through as env vars rather than ever written to a file in
# this repo. `--impure` below is what actually lets that module's
# builtins.getEnv see them; without it (any plain `nix eval`, `nix flake
# check`, `just modules`) they're silently "" and nothing about this feature
# activates -- see that file's own header.
#
# Skippable, as a set: leaving the target host's UUIDs blank means
# autoinstall.service never materializes at all, and the image falls back to
# Calamares or the terminal path -- see liveusb-installer.md.
if [ -z "${NIRE_INSTALLER_ROOT_UUID:-}" ]; then
    read -r -p "Root partition UUID for unattended autoinstall (blank to skip): " NIRE_INSTALLER_ROOT_UUID
fi
if [ -n "$NIRE_INSTALLER_ROOT_UUID" ] && [ -z "${NIRE_INSTALLER_BOOT_UUID:-}" ]; then
    read -r -p "Boot (ESP) partition UUID: " NIRE_INSTALLER_BOOT_UUID
fi
export NIRE_INSTALLER_ROOT_UUID NIRE_INSTALLER_BOOT_UUID

# Wifi for installer-autoinstall.nix's unattended install -- same mechanism
# and same caveats as the UUIDs above.
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

echo "==> building nire-installer for '$NIRE_INSTALLER_TARGET_HOST' (first build pulls down a full ISO closure, expect it to take a while)" >&2
out=$(nix build --impure "${flake}#liveusb-installer" --print-out-paths --no-link)
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
if [ -n "$NIRE_INSTALLER_ROOT_UUID" ]; then
    echo "On boot, autoinstall.service runs unattended once it finds the"
    echo "expected partitions and gets network -- watch it (e.g. over SSH) with:"
    echo "    journalctl -u autoinstall -f"
    echo "A 10s window at the start allows 'systemctl stop autoinstall' to abort."
else
    echo "No autoinstall UUIDs given, so autoinstall.service will not exist on this"
    echo "image -- use Calamares or the terminal path instead. See liveusb-installer.md."
fi

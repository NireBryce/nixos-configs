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

echo "==> building nire-installer (first build pulls down a full ISO closure, expect it to take a while)" >&2
out=$(nix build "${flake}#liveusb-testbed-installer" --print-out-paths --no-link)
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

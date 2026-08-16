#!/usr/bin/env bash
# Unattended install of nire-testbed. Run as autoinstall-testbed.service's
# ExecStart -- see installer-autoinstall-testbed.nix, which substitutes
# @rootUuid@/@bootUuid@ (via lib.replaceStrings, not Nix string
# interpolation -- kept as a real, separately-lintable file instead of an
# inline '' ... '' string, see installer-checks.nix's shellcheck check) and
# wraps this in pkgs.writeShellScript.
#
# Mount-by-UUID is the safety mechanism, not a formality: if the disk
# doesn't have these exact partitions -- wrong machine, a wipe, a
# repartition -- the mount just fails and this refuses to guess or
# partition anything. It can never touch the wrong disk the way a blind
# `parted /dev/sda` could.
set -euo pipefail

root_dev=/dev/disk/by-uuid/@rootUuid@
boot_dev=/dev/disk/by-uuid/@bootUuid@

if [ ! -e "$root_dev" ] || [ ! -e "$boot_dev" ]; then
    echo "autoinstall-testbed: expected partitions not found (root=@rootUuid@ boot=@bootUuid@)." >&2
    echo "autoinstall-testbed: refusing to guess or partition anything -- not installing." >&2
    echo "autoinstall-testbed: this is not the disk hardware-testbed.nix was written for, or it was reformatted. See liveusb-installer.md." >&2
    exit 1
fi

echo "autoinstall-testbed: found the expected partitions. Installing in 10s."
echo "autoinstall-testbed: to abort, from another session: systemctl stop autoinstall-testbed"
sleep 10

mkdir -p /mnt
mount "$root_dev" /mnt
mkdir -p /mnt/boot
mount "$boot_dev" /mnt/boot

echo "autoinstall-testbed: mounted. Running nixos-install --flake -- this can take a while, watch with: journalctl -u autoinstall-testbed -f"
nixos-install \
    --root /mnt \
    --flake path:/etc/nixos-configs#nire-testbed \
    --no-root-passwd

umount -R /mnt || true

echo "autoinstall-testbed: install finished. Reboot manually when ready: 'reboot'."
echo "autoinstall-testbed: deliberately NOT auto-rebooting -- one last chance to notice something's wrong before committing to it."

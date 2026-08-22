#!/usr/bin/env bash
# Unattended install of a target host. Run as autoinstall.service's
# ExecStart -- see installer-autoinstall.nix, which substitutes
# @rootUuid@/@bootUuid@/@targetFlakeAttr@ (via lib.replaceStrings, not Nix
# string interpolation -- kept as a real, separately-lintable file instead of
# an inline '' ... '' string, see installer-checks.nix's shellcheck check)
# and wraps this in pkgs.writeShellScript.
#
# Mount-by-UUID is the safety mechanism, not a formality: if the disk
# doesn't have these exact partitions -- wrong machine, a wipe, a
# repartition -- the mount just fails and this refuses to guess or
# partition anything. It can never touch the wrong disk the way a blind
# `parted /dev/sda` could.
set -euo pipefail

root_dev=/dev/disk/by-uuid/@rootUuid@
boot_dev=/dev/disk/by-uuid/@bootUuid@
target_flake_attr=@targetFlakeAttr@

if [ ! -e "$root_dev" ] || [ ! -e "$boot_dev" ]; then
    echo "autoinstall: expected partitions not found (root=@rootUuid@ boot=@bootUuid@)." >&2
    echo "autoinstall: refusing to guess or partition anything -- not installing." >&2
    echo "autoinstall: this is not the disk the target host's hardware module was written for, or it was reformatted. See liveusb-installer.md." >&2
    exit 1
fi

echo "autoinstall: found the expected partitions. Installing '$target_flake_attr' in 10s."
echo "autoinstall: to abort, from another session: systemctl stop autoinstall"
sleep 10

mkdir -p /mnt
mount "$root_dev" /mnt
mkdir -p /mnt/boot
mount "$boot_dev" /mnt/boot

echo "autoinstall: mounted. Running nixos-install --flake -- this can take a while, watch with: journalctl -u autoinstall -f"
nixos-install \
    --root /mnt \
    --flake "path:/etc/nixos-configs#$target_flake_attr" \
    --no-root-passwd

umount -R /mnt || true

echo "autoinstall: install finished. Reboot manually when ready: 'reboot'."
echo "autoinstall: deliberately NOT auto-rebooting -- one last chance to notice something's wrong before committing to it."

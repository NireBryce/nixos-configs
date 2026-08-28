#! /usr/bin/env bash
# What has changed on / since the blank root-blank snapshot -- i.e. every
# file the impermanence rollback in WARN-impermanence.nix will silently eat
# on the next boot, because nothing named it in environment.persistence.
#
#   root-drift.sh
#
# Read-only, but needs root: it mounts the host's btrfs top level (subvolid 5,
# read-only) to reach the "root" and "root-blank" subvolumes as plain
# directories, which is what `btrfs subvolume find-new` needs -- they are not
# both reachable through the live "/" mount at once. Unmounted again on exit,
# success or failure.
#
# Salvaged 2026-08-22 from ignore/util/misc/fs-diff.sh (2024), which did the
# same find-new trick against an install-time chroot (/mnt/root-blank,
# /mnt/root). This version finds its own device and mountpoint instead of
# assuming /mnt is already set up, so it runs on a live booted host.
#
# Only meaningful on a host that actually imports the `impermanence`
# category -- durandal, tenacity, not cube. Says so and exits cleanly
# if root-blank does not exist rather than guessing.
set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
    echo "Needs root, to mount the btrfs top level. Re-run as:" >&2
    echo >&2
    echo "  sudo $0" >&2
    exit 1
fi

# Read PID 1's mount table, not the caller's -- lsblk/findmnt inside a
# sandboxed shell can describe a different, wrong-looking mount namespace even
# when the caller is genuinely running on the host. Same trick and same
# reasoning as deployed-baseline.sh: mountinfo has a variable number of
# optional fields before the "-" separator, so find it rather than counting
# columns; fstype and source both sit right after it.
device=$(awk '$5=="/"{ for(i=1;i<=NF;i++) if ($i=="-") { print $(i+2); exit } }' /proc/1/mountinfo)

if [[ -z ${device:-} ]]; then
    echo "Could not find the device behind / in /proc/1/mountinfo -- not a btrfs root?" >&2
    exit 1
fi

mnt=$(mktemp -d)
cleanup() { umount "$mnt" 2>/dev/null || true; rmdir "$mnt" 2>/dev/null || true; }
trap cleanup EXIT

mount -o subvol=/,ro "$device" "$mnt"

if [[ ! -d "$mnt/root-blank" || ! -d "$mnt/root" ]]; then
    echo "No root-blank subvolume on this device -- this host does not run" >&2
    echo "the impermanence rollback (see CLAUDE.md, Safety), nothing to diff." >&2
    exit 0
fi

# find-new against root-blank with an unreachably large generation lists
# nothing but reports the subvolume's own current generation -- root-blank is
# written once at creation and never touched again, so that generation is the
# blank baseline every later change on root is measured against.
old_transid=$(btrfs subvolume find-new "$mnt/root-blank" 9999999)
old_transid=${old_transid#transid marker was }

echo "## Files on / not covered by any environment.persistence entry"
echo "## (changed since root-blank's baseline, generation $old_transid)"
echo

btrfs subvolume find-new "$mnt/root" "$old_transid" |
sed '$d' |
cut -f17- -d' ' |
sort |
uniq |
while read -r path; do
    path="/$path"
    if [[ -L $path ]]; then
        : # symlink -- probably a NixOS-managed path already, not real drift
    elif [[ -d $path ]]; then
        : # directory entry, not a file -- find-new lists these too
    else
        echo "$path"
    fi
done

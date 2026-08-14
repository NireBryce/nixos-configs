#! /usr/bin/env bash
# What this machine is ACTUALLY running, in a form you can paste into a doc.
#
#   deployed-baseline.sh
#
# Run it before switching. Everything it prints becomes unrecoverable once the
# new generation boots and nix-collect-garbage runs, and it is the only thing
# that can answer "is what I am about to install different from what works" --
# see lessons-learned.md §24.
#
# Read-only. The btrfs section needs root and is skipped without it.
#
# The load-bearing trick: a system's .drv outlives its inputs' outputs. Stage 1's
# init script is usually garbage collected long before the system it belongs to,
# but the derivation still carries the whole script in its buildPhase, so the
# rollback a machine really boots with can be read without building anything.
#
# Prints no secrets: for each account it reports *where* the password comes
# from, never the hash.
set -euo pipefail

cur=$(readlink -f /run/current-system)
drv=$(nix-store --query --deriver /run/current-system)

echo "## Deployed baseline — $(hostname), $(date +%Y-%m-%d)"
echo
echo "| | |"
echo "|---|---|"
# readlink, NOT readlink -f: -f resolves all the way to the toplevel store path
# and loses the generation number, which is the thing you need at the boot menu.
echo "| generation | $(basename "$(readlink /nix/var/nix/profiles/system)") |"
echo "| toplevel | \`$(basename "$cur")\` |"
echo "| nixos-version | $(nixos-version) |"
echo "| running kernel | $(uname -r) |"
echo "| booted = current | $([ "$(readlink -f /run/booted-system)" = "$cur" ] && echo yes || echo "NO — switched since boot") |"

# initrd flavour. A systemd stage 1 has an initrd-*.service unit in its closure;
# a scripted one has stage-1-init.sh.
if nix derivation show -r "$drv" 2>/dev/null | grep -q 'stage-1-init\.sh'; then
    echo "| stage 1 | scripted |"
else
    echo "| stage 1 | systemd |"
fi
echo

echo '### Kernel command line'
echo
echo '```'
nix derivation show "$drv" 2>/dev/null \
  | python3 -c 'import json,sys; print(list(json.load(sys.stdin).values())[0]["env"].get("kernelParams",""))' \
  | tr ' ' '\n' | grep -v '^$' || true
echo '```'
echo

echo '### Declarative users'
echo
u=$(grep -oE '/nix/store/[a-z0-9]+-users-groups\.json' /run/current-system/activate | head -1 || true)
if [[ -n $u && -e $u ]]; then
    python3 - "$u" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(f"mutableUsers: {d.get('mutableUsers')}")
print()
# Select on having a password source, plus root -- not on isNormalUser, which
# users-groups.json does not carry. Filtering on it silently omitted the only
# account you can actually log into.
for user in d["users"]:
    has_pw = user.get("hashedPasswordFile") or user.get("hashedPassword")
    if not (has_pw or user["name"] == "root"):
        continue
    # where the password comes from, never what it is
    if user.get("hashedPasswordFile"):
        src = f"file {user['hashedPasswordFile']}"
    elif user.get("hashedPassword"):
        src = "hashedPassword set in the config"
    else:
        src = "NONE — no password at all"
    print(f"  {user['name']:<10} uid={user.get('uid')}  password: {src}")
PY
else
    echo "  (no users-groups.json found in the activation script)"
fi
echo

echo '### Filesystems and subvolumes'
echo
echo '```'
# mountinfo has a variable number of optional fields before the "-" separator,
# so find it rather than counting columns: fstype, source and super options all
# sit after it. $5 is the mount point.
grep -E ' (btrfs|vfat) ' /proc/1/mountinfo | awk '{
    for (i = 7; i <= NF; i++) if ($i == "-") { fstype = $(i+1); src = $(i+2); opts = $(i+3); break }
    # vfat has no subvolume, so pull the field out rather than string-chopping
    subv = "-"
    if (match(opts, /subvol=[^,]*/)) subv = substr(opts, RSTART, RLENGTH)
    printf "%-38s %-6s %-22s %s\n", $5, fstype, src, subv
}' | sort
echo '```'
echo
echo "Note: read /proc/1/mountinfo, not findmnt or lsblk. Inside a sandboxed"
echo "shell those two report the namespace they are in, not the host — see"
echo "CLAUDE.md and lessons-learned.md §19."
echo

uid=$(id -u)
if [[ $uid -eq 0 ]]; then
    echo '### btrfs subvolumes'
    echo
    echo '```'
    btrfs subvolume list -a / || true
    echo '```'
    echo
    echo "The /root subvolid matters: after a boot it must CHANGE, or the"
    echo "impermanence rollback silently did not run."
else
    echo "### btrfs subvolumes"
    echo
    echo "Skipped — needs root. Re-run as:"
    echo
    echo '```sh'
    echo "sudo $0"
    echo '```'
fi

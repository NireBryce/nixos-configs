#! /usr/bin/env bash
# What /home carries that nothing is handling -- i.e. what a future wipe of
# /home would delete.
#
#   home-drift.sh
#
# /home is a plain persistent btrfs subvolume on every host (subvol=home, no
# home-blank -- the host hardware modules). Nothing wipes it today; this is
# the audit to run BEFORE ever building such a wipe. Sibling of root-drift.sh
# (which salvaged ignore/util/misc/fs-diff.sh, 2024): that one diffs / against
# root-blank with `btrfs subvolume find-new`, but /home has no blank baseline
# to diff against, so this classifies by observation instead. If a home wipe
# ever exists, find-new against the then-created home-blank is the ongoing
# check and this script is the pre-flight.
#
# Two things count as handled, both read off the running host rather than out
# of the config:
#
#   /persist       a path at or under a mountpoint whose mount comes from the
#                  persist subvolume (impermanence bind mounts), or a symlink
#                  resolving into /persist (the file-shaped form)
#
#   home-manager   a symlink resolving into /nix. HM writes every home.file /
#                  xdg.* entry as a store link, including the recursive=true
#                  shape -- real parent dir, symlink leaves (cf.
#                  hm-collisions.sh) -- and covers the nix profile links
#                  (~/.nix-profile, ~/.nix-defexpr).
#
# Reporting shape: a real directory with NO home-manager link directly inside
# is printed once, with a trailing /, and not descended into -- ~/.cache comes
# out as one line, not a file dump. A directory that does hold HM links is
# descended, because that is where real content hides between them (~/.config).
# Empty directories and sockets/fifos are counted, not listed: nothing to save.
#
# Symlinks resolving nowhere handled -- not /nix, not /persist -- are listed
# separately: usually NixOS-regenerated links (/run/current-system, /etc/static)
# or dangling leftovers; judge those by hand. Files ending in .hm-bak are
# home-manager collision backups (backupFileExtension, enable-home-manager.nix),
# not drift.
#
# Read-only. Needs root: a non-root walk silently under-reports on the
# mode-0700 home dirs it cannot enter, which is exactly the failure an audit
# like this must not have. Meaningful on every host -- what it says about
# /persist applies wherever such mounts exist, today on none of them.
set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
    echo "Needs root: a non-root walk silently skips the home dirs it" >&2
    echo "cannot enter, and a silent gap is the one thing this audit" >&2
    echo "must not have. Re-run as:" >&2
    echo >&2
    echo "  sudo $0" >&2
    exit 1
fi

# PID 1's mount table, not the caller's -- same trick and reasoning as
# root-drift.sh: mountinfo has a variable number of optional fields before
# the "-" separator, so find it rather than counting columns. Field 5 is the
# mountpoint; after the separator sit fstype, source and the superblock
# options. A bind mount out of the persist subvolume shares that subvolume's
# superblock, so its options still say subvol=/persist -- which is what
# distinguishes it from the /home mount (subvol=/home) or from any other
# mount that happens to sit under /home without being persistence.
mapfile -t persist_mounts < <(
    awk '
        $5 ~ /^\/home(\/|$)/ {
            for (i = 1; i <= NF; i++)
                if ($i == "-") {
                    sopts = ""
                    for (j = i + 3; j <= NF; j++) sopts = sopts "," $j
                    if (sopts ~ /(^|,)subvol=\/persist(,|$)/) print $5
                    break
                }
        }' /proc/1/mountinfo
)

tmp=$(mktemp)
cleanup() { rm -f "$tmp"; }
trap cleanup EXIT

# %y = entry type, %l = link target (empty for non-links).
find /home -mindepth 1 -printf '%y\t%l\t%p\n' > "$tmp"

# Pass A: per-parent child counts and symlink classification. The count for a
# directory is only complete once find has moved past it, so the wholesale /
# descend decision happens in pass B, over the same records re-read in path
# order.
declare -A total_kids=()   managed_kids=()
declare -a unhandled_dirs=() unhandled_files=()
declare -a persist_links=() other_links=() nixos_links=()
managed_count=0

# Records are split by hand, not `IFS=$'\t' read kind target path`: tab is
# IFS whitespace, so adjacent tabs collapse and %l's empty field on a
# non-link would swallow the next field, leaving path empty. Splitting from
# the head also lets a tab inside a filename ride along in `path`.
while IFS= read -r rec; do
    kind=${rec%%$'\t'*}; rest=${rec#*$'\t'}
    target=${rest%%$'\t'*}; path=${rest#*$'\t'}
    parent=${path%/*}
    total_kids[$parent]=$(( ${total_kids[$parent]:-0} + 1 ))
    [[ $kind == l ]] || continue

    # Resolve relative targets against the link's directory. HM always writes
    # absolute store paths; this is for hand-made relative links, and an
    # un-normalized ../.. shape that escapes every prefix below simply lands
    # in other_links, where it gets judged by hand anyway.
    t=$target
    [[ $t == /* ]] || t=$parent/$t
    case $t in
        /nix/*)
            managed_kids[$parent]=$(( ${managed_kids[$parent]:-0} + 1 ))
            managed_count=$(( managed_count + 1 )) ;;
        /persist/*)
            persist_links+=("$path -> $target") ;;
        /run/current-system|/run/current-system/*|/run/booted-system|/run/booted-system/*|/run/opengl-driver|/run/opengl-driver/*|/etc/static/*)
            nixos_links+=("$path -> $target") ;;
        *)
            # -e follows the link; false on it means dangling (or a loop)
            [[ -e $path ]] || target="$target (dangling)"
            other_links+=("$path -> $target") ;;
    esac
done < "$tmp"

LC_ALL=C sort -t$'\t' -k3,3 -o "$tmp" "$tmp"

# Pass B: emit. Path order puts a directory before its contents, so once a
# directory is reported wholesale its subtree prunes via the ancestor walk
# instead of being walked.
declare -A reported=()
declare -a persist_mount_lines=()
empty_count=0 special_count=0

while IFS= read -r rec; do
    kind=${rec%%$'\t'*}; rest=${rec#*$'\t'}
    target=${rest%%$'\t'*}; path=${rest#*$'\t'}
    handled=0
    if (( ${#persist_mounts[@]} > 0 )); then
        for mp in "${persist_mounts[@]}"; do
            if [[ $path == "$mp" ]]; then
                persist_mount_lines+=("$mp/")
                handled=1
            elif [[ $path == "$mp"/* ]]; then
                handled=1
            fi
            if [[ $handled -eq 1 ]]; then break; fi
        done
    fi
    # `if (( ))`, not `(( )) &&`: the &&-list leaves status 1 on the
    # fall-through, and that status is the last thing some loop-body
    # iterations leave behind -- set -e would kill the script there
    if (( handled )); then continue; fi

    # any ancestor already reported wholesale covers this entry
    p=$path
    while [[ $p != /home ]]; do
        p=${p%/*}
        if [[ -n ${reported[$p]:-} ]]; then
            handled=1
            break
        fi
    done
    if (( handled )); then continue; fi

    # links were all classified in pass A, wholesale-dir or not
    if [[ $kind == l ]]; then continue; fi

    case $kind in
        d)
            # HM links live directly inside: descend, so the real content
            # between them surfaces rather than hiding behind the dir name
            if (( ${managed_kids[$path]:-0} > 0 )); then continue; fi
            if [[ -z ${total_kids[$path]:-} ]]; then
                empty_count=$(( empty_count + 1 ))
                continue
            fi
            unhandled_dirs+=("$path/")
            reported[$path]=1 ;;
        f)
            unhandled_files+=("$path") ;;
        *)
            special_count=$(( special_count + 1 )) ;;
    esac
done < "$tmp"

echo "## /home content that nothing is handling"
echo "## (no /persist entry behind it, no home-manager link regenerating it)"
echo "## -- i.e. what a future wipe of /home would delete. Directories with"
echo "## no home-manager link directly inside are collapsed to one line;"
echo "## empty dirs ($empty_count) and sockets/fifos ($special_count) are"
echo "## counted in this header instead of listed."
echo

echo "## not persisted, not home-manager-managed"
if (( ${#unhandled_dirs[@]} + ${#unhandled_files[@]} == 0 )); then
    echo "(nothing -- /home is fully covered)"
else
    { printf '%s\n' "${unhandled_dirs[@]}" "${unhandled_files[@]}"; } |
        LC_ALL=C sort
fi
echo

echo "## persisted through /persist (bind mounts under /home, plus links into /persist)"
if (( ${#persist_mount_lines[@]} + ${#persist_links[@]} == 0 )); then
    echo "(none found -- check /proc/1/mountinfo if that surprises you)"
else
    { printf '%s\n' "${persist_mount_lines[@]}" "${persist_links[@]}"; } |
        LC_ALL=C sort
fi
echo

echo "## NixOS-regenerated symlinks (informational)"
if (( ${#nixos_links[@]} == 0 )); then
    echo "(none)"
else
    printf '%s\n' "${nixos_links[@]}" | LC_ALL=C sort
fi
echo

echo "## other symlinks -- not /nix, not /persist; judge these by hand"
if (( ${#other_links[@]} == 0 )); then
    echo "(none)"
else
    printf '%s\n' "${other_links[@]}" | LC_ALL=C sort
fi
echo

echo "## summary: $managed_count home-manager links skipped (recreated on switch)," \
     "$empty_count empty dirs, $special_count sockets/fifos ignored"

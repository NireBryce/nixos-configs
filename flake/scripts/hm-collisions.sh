#! /usr/bin/env bash
# Which files Home Manager will take over, and whether any would collide.
#
#   hm-collisions.sh [host] [user]
#
# HM will not silently overwrite a file it does not already own. Without
# home-manager.backupFileExtension, check-link-targets.sh aborts activation with
# "Existing file '<path>' would be clobbered"; with it set -- which it is here,
# to "hm-bak" in enable-home-manager.nix -- each such file is renamed aside and
# the switch continues. Either way, this answers before switching which paths
# are affected.
#
# Evaluation plus stat(2). Builds nothing, activates nothing, writes nothing.
#
# Classify by where a path RESOLVES, not by whether its leaf is a symlink. A
# real case from tenacity that a naive `[ -L ]` test gets wrong, reporting it
# as a collision when it is not:
#
#   ~/.config/broot     a real directory whose contents are HM symlinks. Its
#                       home.file entry is `recursive = true`, so HM links the
#                       files individually and leaves the directory real -- that
#                       is the correct end state, not a conflict
#
# Only meaningful run on the host itself: it inspects that machine's $HOME.
set -euo pipefail

host=${1:-nire-durandal}
user=${2:-elly}

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
flake_dir=$(dirname -- "$script_dir")

echo "home-manager collisions for ${user}@${host}, against $HOME"
echo

# target + recursive per entry. `recursive` is the bit that decides whether an
# existing directory is a conflict or the expected shape.
entries=$(cd "$flake_dir" && nix eval --json \
    ".#nixosConfigurations.${host}.config.home-manager.users.${user}.home.file" \
    --apply 'fs: builtins.mapAttrs (_: v: { inherit (v) target; recursive = v.recursive or false; }) fs')

python3 "$script_dir/hm_collisions.py" "$entries"

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-22 — the ~/.just/.justfile false-positive collision case
#
# just.nix used to place ~/.just/.justfile (a copy of ~/.justfile's content)
# and ~/.just itself (a whole-directory symlink), alongside ~/.justfile. This
# script's `[ -L ]`-vs-resolved-target distinction was written to handle it:
# ~/.just/.justfile's leaf is a plain file, but it resolves into
# home-manager-files because ~/.just, its parent, is the symlink -- so a naive
# leaf-only symlink check reported it as a collision when it was not.
#
# Removed from just.nix the same day, once `just -g` was straced and found to
# open ~/.justfile directly -- never ~/.just/.justfile, on any version this
# repo has run. Nothing was reading the file this case existed to classify.
# The classification logic itself (resolve, don't just test -L) stays; it is
# still what makes the ~/.config/broot case above correct.

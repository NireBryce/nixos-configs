#! /usr/bin/env bash
# Which files Home Manager will take over, and whether any would collide.
#
#   hm-collisions.sh [host] [user]
#
# HM refuses to overwrite a file it does not already own -- check-link-targets.sh
# aborts activation with "Existing file '<path>' would be clobbered". This
# answers, before switching, whether that is going to happen. Read
# home-manager-cutover.md for what to do if it is.
#
# Evaluation plus stat(2). Builds nothing, activates nothing, writes nothing.
#
# Classify by where a path RESOLVES, not by whether its leaf is a symlink. Two
# real cases from tenacity that a naive `[ -L ]` test gets wrong, both of which
# it reports as collisions when they are not:
#
#   ~/.just/.justfile   ~/.just is itself a symlink into home-manager-files, so
#                       the file *inside* it is a plain file
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

HOME_DIR=$HOME python3 - "$entries" <<'PY'
import json, os, sys

home = os.environ["HOME_DIR"]
entries = json.loads(sys.argv[1])

owned, absent, collisions, recursive_dirs = [], [], [], []

for _, v in sorted(entries.items()):
    target = v["target"]
    path = target if target.startswith("/") else os.path.join(home, target)

    if not os.path.lexists(path):
        absent.append(path)
        continue

    resolved = os.path.realpath(path)

    if resolved.startswith("/nix/store/"):
        owned.append(path)
    elif v["recursive"] and os.path.isdir(path):
        # HM links the contents, not the directory, so a real directory here is
        # what a previous activation produced rather than something in the way.
        recursive_dirs.append(path)
    else:
        collisions.append(path)

print(f"  {len(owned):>3}  already home-manager owned (resolve into /nix/store)")
print(f"  {len(absent):>3}  do not exist yet, will be created")
print(f"  {len(recursive_dirs):>3}  real directories for recursive entries -- expected, not conflicts")
print(f"  {len(collisions):>3}  COLLISIONS")
print()

if recursive_dirs:
    print("recursive entries (HM links the contents, directory stays real):")
    for p in recursive_dirs:
        print(f"    {p}")
    print()

if collisions:
    print("COLLISIONS -- activation will abort on these:")
    for p in collisions:
        print(f"    {p}")
    print()
    print("Set home-manager.backupFileExtension in")
    print("modules/nire/system/home-manager/enable-home-manager.nix, switch,")
    print("check the *.hm-bak files, then REMOVE the option again so future")
    print("collisions stay loud. See linux-flake/home-manager-cutover.md.")
    raise SystemExit(1)

print("No collisions. This is a relink.")
PY

#!/usr/bin/env python3
"""Classify Home Manager home.file targets against the real $HOME.

    hm_collisions.py '<json of {name: {target, recursive}}>'

Called by hm-collisions.sh with the evaluated entries. Classifies by where a
path RESOLVES, not by whether its leaf is a symlink -- see that script's
header for the ~/.config/broot case. Exits 1 if anything collides.
"""
import json
import os
import sys


def classify(entries, home):
    """Return (owned, absent, collisions, recursive_dirs) path lists."""
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
            # HM links the contents, not the directory, so a real directory
            # here is what a previous activation produced rather than
            # something in the way.
            recursive_dirs.append(path)
        else:
            collisions.append(path)
    return owned, absent, collisions, recursive_dirs


def report(owned, absent, collisions, recursive_dirs):
    """Lines for the summary; the caller exits non-zero on collisions."""
    out = [
        f"  {len(owned):>3}  already home-manager owned (resolve into /nix/store)",
        f"  {len(absent):>3}  do not exist yet, will be created",
        f"  {len(recursive_dirs):>3}  real directories for recursive entries -- expected, not conflicts",
        f"  {len(collisions):>3}  COLLISIONS",
        "",
    ]

    if recursive_dirs:
        out.append("recursive entries (HM links the contents, directory stays real):")
        out.extend(f"    {p}" for p in recursive_dirs)
        out.append("")

    if collisions:
        out.append("COLLISIONS -- HM does not own these paths yet:")
        out.extend(f"    {p}" for p in collisions)
        out.append("")
        out.append("Not fatal. home-manager.backupFileExtension is set permanently to")
        out.append("\"hm-bak\" in modules/general-config/system/home-manager/enable-home-manager.nix,")
        out.append("so activation renames each of these to <file>.hm-bak and carries on")
        out.append("rather than aborting half-applied. Switch, then read the .hm-bak")
        out.append("files: they are untracked state worth understanding, not noise.")
    else:
        out.append("No collisions. This is a relink.")
    return out


def main(argv):
    entries = json.loads(argv[1])
    owned, absent, collisions, recursive_dirs = classify(entries, os.environ["HOME"])
    print("\n".join(report(owned, absent, collisions, recursive_dirs)))
    return 1 if collisions else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

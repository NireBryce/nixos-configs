#!/usr/bin/env python3
"""Report what moved between two host-fingerprint.nix evaluations.

    diff_fingerprint.py <before.json> <after.json>

Called by diff-config.sh with the two `nix eval --json` outputs. Exits 0
whether or not they differ -- the report is the result, not the status.
"""
import json
import sys


def report(before, after):
    """Lines describing how fingerprint `b` (before) became `a` (after)."""
    out = []
    if before["toplevel"] == after["toplevel"]:
        out.append("  toplevel drvPath IDENTICAL -- byte-for-byte, no behaviour change")
        out.append(f"    {after['toplevel']}")
        return out

    out.append("  toplevel drvPath DIFFERS")
    out.append(f"    before {before['toplevel']}")
    out.append(f"    after  {after['toplevel']}")
    out.append("")

    changed = False
    for key in before:
        if key == "toplevel" or before[key] == after[key]:
            continue
        changed = True
        bv, av = before[key], after[key]
        if isinstance(bv, list) and sorted(map(str, bv)) == sorted(map(str, av)):
            out.append(f"  {key}: SAME SET, ORDER ONLY ({len(bv)} items)")
            continue
        if isinstance(bv, list):
            bs, as_ = set(map(str, bv)), set(map(str, av))
            if bs - as_:
                out.append(f"  {key}: removed {sorted(bs - as_)}")
            if as_ - bs:
                out.append(f"  {key}: added   {sorted(as_ - bs)}")
        elif isinstance(bv, dict):
            # only the keys that moved -- printing both dicts whole is
            # unreadable, and homeFileHashes has dozens of entries
            for kk in sorted(set(bv) | set(av)):
                if kk not in av:
                    out.append(f"  {key}: removed {kk!r}")
                elif kk not in bv:
                    out.append(f"  {key}: added   {kk!r}")
                elif bv[kk] != av[kk]:
                    out.append(f"  {key}: changed {kk!r}")
        else:
            out.append(f"  {key}: {bv!r} -> {av!r}")

    if not changed:
        out.append("  no attribute in the fingerprint differs.")
        out.append("  the change is real but outside what host-fingerprint.nix samples;")
        out.append("  add the relevant attribute there to see it.")
    return out


def main(argv):
    with open(argv[1]) as handle:
        before = json.load(handle)
    with open(argv[2]) as handle:
        after = json.load(handle)
    print("\n".join(report(before, after)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

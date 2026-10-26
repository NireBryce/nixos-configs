#!/usr/bin/env python3
"""Report what moved between two host-fingerprint.nix evaluations.

    diff_fingerprint.py <before.json> <after.json>

Called by diff-config.sh with the two `nix eval --json` outputs. Exits 0
whether or not they differ -- the report is the result, not the status.
"""
import json
import sys


def report(b, a):
    """Lines describing how fingerprint `b` (before) became `a` (after)."""
    out = []
    if b["toplevel"] == a["toplevel"]:
        out.append("  toplevel drvPath IDENTICAL -- byte-for-byte, no behaviour change")
        out.append(f"    {a['toplevel']}")
        return out

    out.append("  toplevel drvPath DIFFERS")
    out.append(f"    before {b['toplevel']}")
    out.append(f"    after  {a['toplevel']}")
    out.append("")

    changed = False
    for k in b:
        if k == "toplevel" or b[k] == a[k]:
            continue
        changed = True
        bv, av = b[k], a[k]
        if isinstance(bv, list) and sorted(map(str, bv)) == sorted(map(str, av)):
            out.append(f"  {k}: SAME SET, ORDER ONLY ({len(bv)} items)")
            continue
        if isinstance(bv, list):
            bs, as_ = set(map(str, bv)), set(map(str, av))
            if bs - as_:
                out.append(f"  {k}: removed {sorted(bs - as_)}")
            if as_ - bs:
                out.append(f"  {k}: added   {sorted(as_ - bs)}")
        elif isinstance(bv, dict):
            # only the keys that moved -- printing both dicts whole is
            # unreadable, and homeFileHashes has dozens of entries
            for kk in sorted(set(bv) | set(av)):
                if kk not in av:
                    out.append(f"  {k}: removed {kk!r}")
                elif kk not in bv:
                    out.append(f"  {k}: added   {kk!r}")
                elif bv[kk] != av[kk]:
                    out.append(f"  {k}: changed {kk!r}")
        else:
            out.append(f"  {k}: {bv!r} -> {av!r}")

    if not changed:
        out.append("  no attribute in the fingerprint differs.")
        out.append("  the change is real but outside what host-fingerprint.nix samples;")
        out.append("  add the relevant attribute there to see it.")
    return out


def main(argv):
    with open(argv[1]) as f:
        b = json.load(f)
    with open(argv[2]) as f:
        a = json.load(f)
    print("\n".join(report(b, a)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

#!/usr/bin/env python3
"""Split every in-scope doc into N balanced groups for parallel auditing.

Each doc lands in exactly one group. Kept together: `X.md` with
`X-for-agents.md` and `X-history.md`, and a symlink with its target. Docs
are clustered by area (wiki subfolder; a rule's `paths:` frontmatter, or
its own name; skills; AGENTS.md) and groups are filled greedily by word
count, largest unit first, preferring a group that already holds the
unit's area unless that group is over the balanced target. Output: each
group's word total and files.

Self-check (exit 1): any in-scope doc unassigned or assigned twice, or a
unit split across groups.

    doc_partition.py [--agents N] [--root DIR]
"""
import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import docscope  # noqa: E402

SUFFIXES = ("-for-agents", "-history")
WIKI_AREAS = ("categories", "homelab", "experiments", "lessons-learned")


def words(root, rel):
    p = Path(root) / rel
    return 0 if p.is_symlink() else len(p.read_text(errors="replace").split())


def units(root, docs):
    """[{files, words}]: files that must stay together (sibling sets, symlink + target)."""
    root = Path(root)
    parent = {d: d for d in docs}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        if a in parent and b in parent:
            parent[find(a)] = find(b)

    for d in docs:
        p = root / d
        if p.is_symlink():
            union(d, (Path(d).parent / p.readlink()).as_posix()
                  if not p.readlink().is_absolute() else d)
        stem = d[:-3] if d.endswith(".md") else d
        for s in SUFFIXES:
            if stem.endswith(s):
                union(d, stem[:-len(s)] + ".md")
    groups = {}
    for d in docs:
        groups.setdefault(find(d), []).append(d)
    return [dict(files=sorted(f)) for f in groups.values()]


def rule_area(root, rel):
    text = (Path(root) / rel).read_text(errors="replace")
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    globs = re.findall(r'^\s*-\s*"?([^"\n]+)"?', m.group(1), re.M) if m else []
    for a in WIKI_AREAS:
        if any(a.removesuffix("-config") in g for g in globs):
            return a
    return "rule:" + Path(rel).stem


def area(root, rel):
    parts = rel.split("/")
    if parts[0] == "wiki":
        return parts[1] if len(parts) > 2 else "wiki"
    if rel.startswith(".agents/rules/"):
        return rule_area(root, rel)
    if rel.startswith(".agents/skills/"):
        return "skills"
    return "core"


def partition(root, n):
    docs = docscope.docs(root)
    us = units(root, docs)
    for u in us:
        u["words"] = sum(words(root, f) for f in u["files"])
        u["area"] = area(root, u["files"][0])
    target = sum(u["words"] for u in us) / n
    groups = [dict(words=0, files=[], areas=set()) for _ in range(n)]
    for u in sorted(us, key=lambda u: (-u["words"], u["files"][0])):
        same = [g for g in groups if u["area"] in g["areas"]
                and g["words"] + u["words"] <= target * 1.15]
        g = min(same or groups, key=lambda g: g["words"])
        g["words"] += u["words"]
        g["files"] += u["files"]
        g["areas"].add(u["area"])
    return docs, us, groups


def verify(docs, groups, us=None):
    """List of problems; empty means every doc is in exactly one group."""
    seen, problems = {}, []
    for i, g in enumerate(groups):
        for f in g["files"]:
            if f in seen:
                problems.append(f"{f}: assigned twice (groups {seen[f]} and {i})")
            seen[f] = i
    problems += [f"{d}: unassigned" for d in docs if d not in seen]
    problems += [f"{f}: not an in-scope doc" for f in seen if f not in set(docs)]
    for u in us or []:
        if len({seen.get(f) for f in u["files"]}) > 1:
            problems.append(f"unit split across groups: {u['files']}")
    return problems


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--agents", type=int, default=5)
    ap.add_argument("--root", default=str(docscope.ROOT))
    a = ap.parse_args(argv)
    docs, us, groups = partition(a.root, a.agents)
    for i, g in enumerate(groups, 1):
        print(f"group {i}: {g['words']} words, {len(g['files'])} files "
              f"(areas: {', '.join(sorted(g['areas'])) or '-'})")
        for f in sorted(g["files"]):
            print(f"  {f}")
    problems = verify(docs, groups, us)
    for p in problems:
        print(f"SELF-CHECK FAILED: {p}", file=sys.stderr)
    print(f"\n{len(docs)} docs, {sum(g['words'] for g in groups)} words, "
          f"{a.agents} groups; self-check {'FAILED' if problems else 'ok'}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

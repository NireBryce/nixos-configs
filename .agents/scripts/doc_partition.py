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
WIKI_AREAS = ("config-structure", "homelab", "experiments", "agent-lessons-learned")


def words(root, rel):
    doc_path = Path(root) / rel
    return 0 if doc_path.is_symlink() else len(doc_path.read_text(errors="replace").split())


def units(root, docs):
    """[{files, words}]: files that must stay together (sibling sets, symlink + target)."""
    root = Path(root)
    parent = {doc_name: doc_name for doc_name in docs}

    def find(doc):
        while parent[doc] != doc:
            parent[doc] = parent[parent[doc]]
            doc = parent[doc]
        return doc

    def union(first, second):
        if first in parent and second in parent:
            parent[find(first)] = find(second)

    for doc_name in docs:
        doc_path = root / doc_name
        if doc_path.is_symlink():
            union(doc_name, (Path(doc_name).parent / doc_path.readlink()).as_posix()
                  if not doc_path.readlink().is_absolute() else doc_name)
        stem = doc_name[:-3] if doc_name.endswith(".md") else doc_name
        for suffix in SUFFIXES:
            if stem.endswith(suffix):
                union(doc_name, stem[:-len(suffix)] + ".md")
    groups = {}
    for doc_name in docs:
        groups.setdefault(find(doc_name), []).append(doc_name)
    return [dict(files=sorted(unit_files)) for unit_files in groups.values()]


def rule_area(root, rel):
    text = (Path(root) / rel).read_text(errors="replace")
    match = re.match(r"---\n(.*?)\n---", text, re.S)
    globs = re.findall(r'^\s*-\s*"?([^"\n]+)"?', match.group(1), re.M) if match else []
    for area in WIKI_AREAS:
        if any(area.removesuffix("-config") in glob for glob in globs):
            return area
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


def partition(root, group_count):
    docs = docscope.docs(root)
    us = units(root, docs)
    for unit in us:
        unit["words"] = sum(words(root, file_name) for file_name in unit["files"])
        unit["area"] = area(root, unit["files"][0])
    target = sum(unit["words"] for unit in us) / group_count
    groups = [dict(words=0, files=[], areas=set()) for _ in range(group_count)]
    for unit in sorted(us, key=lambda unit: (-unit["words"], unit["files"][0])):
        same = [group for group in groups if unit["area"] in group["areas"]
                and group["words"] + unit["words"] <= target * 1.15]
        group = min(same or groups, key=lambda group: group["words"])
        group["words"] += unit["words"]
        group["files"] += unit["files"]
        group["areas"].add(unit["area"])
    return docs, us, groups


def verify(docs, groups, us=None):
    """List of problems; empty means every doc is in exactly one group."""
    seen, problems = {}, []
    for group_index, group in enumerate(groups):
        for file_name in group["files"]:
            if file_name in seen:
                problems.append(f"{file_name}: assigned twice (groups {seen[file_name]} and {group_index})")
            seen[file_name] = group_index
    problems += [f"{doc}: unassigned" for doc in docs if doc not in seen]
    problems += [f"{file_name}: not an in-scope doc" for file_name in seen if file_name not in set(docs)]
    for unit in us or []:
        if len({seen.get(file_name) for file_name in unit["files"]}) > 1:
            problems.append(f"unit split across groups: {unit['files']}")
    return problems


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--agents", type=int, default=5)
    ap.add_argument("--root", default=str(docscope.ROOT))
    args = ap.parse_args(argv)
    docs, us, groups = partition(args.root, args.agents)
    for group_number, group in enumerate(groups, 1):
        print(f"group {group_number}: {group['words']} words, {len(group['files'])} files "
              f"(areas: {', '.join(sorted(group['areas'])) or '-'})")
        for file_name in sorted(group["files"]):
            print(f"  {file_name}")
    problems = verify(docs, groups, us)
    for problem in problems:
        print(f"SELF-CHECK FAILED: {problem}", file=sys.stderr)
    print(f"\n{len(docs)} docs, {sum(group['words'] for group in groups)} words, "
          f"{args.agents} groups; self-check {'FAILED' if problems else 'ok'}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

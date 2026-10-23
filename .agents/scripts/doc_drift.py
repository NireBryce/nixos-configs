#!/usr/bin/env python3
"""Which docs have the most code change under what they cite?

Answers "where should a doc-accuracy audit start": for each in-scope doc
(docscope.py), take its `_Last modified:_` date (skills/rules without one:
the file's last commit date), collect the repo paths it cites (backtick and
markdown-link tokens that resolve to tracked files or directories), and
count commits touching those paths strictly after that date. Docs
themselves (*.md) are not counted as changes: a doc citing a doc is not
drift in the code it describes. Cited directories shallower than
MIN_DIR_DEPTH components (`flake/modules`) are ignored as too broad. Paths renamed or removed don't resolve and
are skipped.

Ranked by commits since, then cited-path count. Reporting only: exit 0.
One `git log --name-only` pass, so it is fast.

    doc_drift.py [--top N] [--root DIR]
"""
import argparse
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import docscope  # noqa: E402


MIN_DIR_DEPTH = 3


def change_log(root):
    """{path: sorted [(date, sha)]} for every non-doc file ever touched."""
    out = docscope.git(root, "log", "--format=@%H %cs", "--name-only",
                       "--no-renames")
    hist = defaultdict(set)
    sha = date = None
    for line in out.splitlines():
        if line.startswith("@"):
            sha, date = line[1:].split()
        elif line and sha and not line.endswith(".md"):
            hist[line].add((date, sha))
    return hist


def commits_after(hist, path, date, dir_files):
    """Set of shas touching `path` (a file, or a directory) after `date`."""
    keys = dir_files(path)
    return {sha for k in keys for d, sha in hist.get(k, ()) if d > date}


def rank(root):
    root = Path(root)
    index = docscope.Index(root)
    hist = change_log(root)
    by_dir = defaultdict(list)
    for f in hist:
        parts = f.split("/")
        for i in range(1, len(parts)):
            by_dir["/".join(parts[:i])].append(f)

    def dir_files(p):
        return by_dir[p] if p in index.dirs else [p]

    rows = []
    for rel in docscope.docs(root):
        if (root / rel).is_symlink():
            continue
        date, src = docscope.last_modified(root, rel)
        if not date:
            continue
        paths = docscope.cited((root / rel).read_text(errors="replace"), index)
        # Directories shallower than MIN_DIR_DEPTH (flake/modules) are
        # "everything changed", not a signal about this doc.
        paths = {p for p in paths if p != rel and not p.endswith(".md")
                 and (p in index.files or p.count("/") + 1 >= MIN_DIR_DEPTH)}
        per = {p: commits_after(hist, p, date, dir_files) for p in paths}
        allc = set().union(*per.values()) if per else set()
        top = sorted(per, key=lambda p: (-len(per[p]), p))[:3]
        rows.append(dict(doc=rel, date=date, src=src, cited=len(paths),
                         commits=len(allc),
                         top=[(p, len(per[p])) for p in top if per[p]]))
    rows.sort(key=lambda r: (-r["commits"], -r["cited"], r["doc"]))
    return rows


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--top", type=int, default=20)
    ap.add_argument("--root", default=str(docscope.ROOT))
    a = ap.parse_args(argv)
    rows = rank(a.root)
    print(f"{'commits':>7} {'cited':>5}  {'modified':<12} doc  [most-changed cited paths]")
    for r in rows[:a.top]:
        mark = "" if r["src"] == "line" else "*"
        top = ", ".join(f"{p} ({n})" for p, n in r["top"])
        print(f"{r['commits']:>7} {r['cited']:>5}  {r['date'] + mark:<12} "
              f"{r['doc']}  [{top}]")
    print(f"\n{min(a.top, len(rows))} of {len(rows)} docs; * = date from last "
          "git commit (no `_Last modified:_` line); *.md changes not counted.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

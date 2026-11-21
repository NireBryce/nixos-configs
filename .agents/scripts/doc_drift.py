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
    return {sha for key in keys for entry_date, sha in hist.get(key, ()) if entry_date > date}


def rank(root):
    root = Path(root)
    index = docscope.Index(root)
    hist = change_log(root)
    by_dir = defaultdict(list)
    for file_name in hist:
        parts = file_name.split("/")
        for depth in range(1, len(parts)):
            by_dir["/".join(parts[:depth])].append(file_name)

    def dir_files(path):
        return by_dir[path] if path in index.dirs else [path]

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
        paths = {candidate for candidate in paths if candidate != rel and not candidate.endswith(".md")
                 and (candidate in index.files or candidate.count("/") + 1 >= MIN_DIR_DEPTH)}
        per = {candidate: commits_after(hist, candidate, date, dir_files) for candidate in paths}
        allc = set().union(*per.values()) if per else set()
        top = sorted(per, key=lambda candidate: (-len(per[candidate]), candidate))[:3]
        rows.append(dict(doc=rel, date=date, src=src, cited=len(paths),
                         commits=len(allc),
                         top=[(candidate, len(per[candidate])) for candidate in top if per[candidate]]))
    rows.sort(key=lambda row: (-row["commits"], -row["cited"], row["doc"]))
    return rows


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--top", type=int, default=20)
    ap.add_argument("--root", default=str(docscope.ROOT))
    args = ap.parse_args(argv)
    rows = rank(args.root)
    print(f"{'commits':>7} {'cited':>5}  {'modified':<12} doc  [most-changed cited paths]")
    for row in rows[:args.top]:
        mark = "" if row["src"] == "line" else "*"
        top = ", ".join(f"{path} ({count})" for path, count in row["top"])
        print(f"{row['commits']:>7} {row['cited']:>5}  {row['date'] + mark:<12} "
              f"{row['doc']}  [{top}]")
    print(f"\n{min(args.top, len(rows))} of {len(rows)} docs; * = date from last "
          "git commit (no `_Last modified:_` line); *.md changes not counted.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""`just agent lessons [<path>...] [--command CMD]`: what applies here.

For each path (file or directory, relative to the cwd), every
.agents/lessons-map.toml topic it falls under: the topic's reminder, where
the full rule lives, and the wiki/lessons-learned.md index line of each of
its lessons. `--command` does the same for a shell command.

With no arguments: the files this branch changes against the merge base
with origin/experimental, plus untracked ones -- the question skill
`review` asks of a diff, answered for every touched area at once.

Replaces reading the whole lessons index (or grepping it for a path) before
working in an area. Matching is lessons_map.py's, shared with the reminder
hook, so this prints exactly what the hook would deliver, plus the topics
too broad to remind on (remind_on = "never").
"""
import argparse
import pathlib
import re
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'hooks'))
import lessons_map  # noqa: E402

ENTRY = re.compile(r'^- \*\*§(\d+)\*\* ')


def git(root, *args):
    r = subprocess.run(['git', '-C', str(root), *args],
                       capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ''


def branch_files(root):
    base = git(root, 'merge-base', 'HEAD', 'origin/experimental').strip()
    changed = git(root, 'diff', '--name-only', '-z', base) if base else ''
    untracked = git(root, 'ls-files', '--others', '--exclude-standard', '-z')
    return sorted({f for f in (changed + untracked).split('\0') if f})


def index_lines(root):
    page = root / 'wiki' / 'lessons-learned.md'
    out = {}
    for line in page.read_text().splitlines():
        m = ENTRY.match(line)
        if m:
            out[int(m.group(1))] = line[2:]
    return out


def expand(root, cwd, arg):
    """A path argument as repo-relative files; a directory is every tracked
    file beneath it, so `lessons flake/modules/general-config/homelab`
    reports the area, not nothing."""
    p = (cwd / arg).resolve()
    if p != root and root not in p.parents:
        print(f'lessons: {arg} is outside {root}; skipped', file=sys.stderr)
        return []
    rel = p.relative_to(root).as_posix() if p != root else ''
    if p.is_dir():
        listed = [f for f in git(root, 'ls-files', '-z', '--', rel or '.').split('\0') if f]
        return listed or [rel]
    return [rel]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('paths', nargs='*')
    ap.add_argument('--command', action='append', default=[])
    args = ap.parse_args()

    cwd = pathlib.Path.cwd()
    root = lessons_map.find_root(cwd)
    if root is None:
        print('lessons: no .agents/lessons-map.toml above this directory',
              file=sys.stderr)
        return 2
    topics = lessons_map.load(root)

    hits = {}  # topic id -> (topic, [what matched])
    files = []
    for a in args.paths:
        files += expand(root, cwd, a)
    if not args.paths and not args.command:
        files = branch_files(root)
        if not files:
            print('lessons: no changed files against origin/experimental; '
                  'pass a path')
            return 0
    for f in files:
        for t in lessons_map.match_path(topics, f):
            hits.setdefault(t['id'], (t, []))[1].append(f)
    for c in args.command:
        for t in lessons_map.match_command(topics, c):
            hits.setdefault(t['id'], (t, []))[1].append(f'$ {c}')

    if not hits:
        print('lessons: no topic covers '
              + (', '.join(files + args.command) or 'that'))
        return 0
    index = index_lines(root)
    for tid, (t, matched) in hits.items():
        shown = matched[:3] + ([f'... {len(matched) - 3} more']
                               if len(matched) > 3 else [])
        print(f"== {tid}  ({', '.join(shown)})")
        if t.get('remind'):
            when = ' (on creating a file)' if t.get('remind_on') == 'create' else ''
            print(f"   {t['remind']}{when}")
        print(f"   full rule: {lessons_map.pointers(t)}")
        for n in t.get('lessons', []):
            print(f"   {index.get(n, f'§{n} (no index entry)')}")
        print()
    return 0


if __name__ == '__main__':
    sys.exit(main())

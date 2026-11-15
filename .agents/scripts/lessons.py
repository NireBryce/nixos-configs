#!/usr/bin/env python3
"""`just agent lessons [<path>...] [--command CMD]`: what applies here.

For each path (file or directory, relative to the cwd), every
.agents/lessons-map.toml topic it falls under: the topic's reminder, where
the full rule lives, and the wiki/agent-lessons-learned.md index line of each of
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
    result = subprocess.run(['git', '-C', str(root), *args],
                       capture_output=True, text=True)
    return result.stdout if result.returncode == 0 else ''


def branch_files(root):
    base = git(root, 'merge-base', 'HEAD', 'origin/experimental').strip()
    changed = git(root, 'diff', '--name-only', '-z', base) if base else ''
    untracked = git(root, 'ls-files', '--others', '--exclude-standard', '-z')
    return sorted({file_name for file_name in (changed + untracked).split('\0') if file_name})


def index_lines(root):
    page = root / 'wiki' / 'agent-lessons-learned.md'
    out = {}
    for line in page.read_text().splitlines():
        match = ENTRY.match(line)
        if match:
            out[int(match.group(1))] = line[2:]
    return out


def expand(root, cwd, arg):
    """A path argument as repo-relative files; a directory is every tracked
    file beneath it, so `lessons flake/modules/homelab-config/homelab`
    reports the area, not nothing."""
    resolved = (cwd / arg).resolve()
    if resolved != root and root not in resolved.parents:
        print(f'lessons: {arg} is outside {root}; skipped', file=sys.stderr)
        return []
    rel = resolved.relative_to(root).as_posix() if resolved != root else ''
    if resolved.is_dir():
        listed = [file_name for file_name in git(root, 'ls-files', '-z', '--', rel or '.').split('\0') if file_name]
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
    for arg in args.paths:
        files += expand(root, cwd, arg)
    if not args.paths and not args.command:
        files = branch_files(root)
        if not files:
            print('lessons: no changed files against origin/experimental; '
                  'pass a path')
            return 0
    for file_name in files:
        for topic in lessons_map.match_path(topics, file_name):
            hits.setdefault(topic['id'], (topic, []))[1].append(file_name)
    for command in args.command:
        for topic in lessons_map.match_command(topics, command):
            hits.setdefault(topic['id'], (topic, []))[1].append(f'$ {command}')

    if not hits:
        print('lessons: no topic covers '
              + (', '.join(files + args.command) or 'that'))
        return 0
    index = index_lines(root)
    for tid, (topic, matched) in hits.items():
        shown = matched[:3] + ([f'... {len(matched) - 3} more']
                               if len(matched) > 3 else [])
        print(f"== {tid}  ({', '.join(shown)})")
        if topic.get('remind'):
            when = ' (on creating a file)' if topic.get('remind_on') == 'create' else ''
            print(f"   {topic['remind']}{when}")
        print(f"   full rule: {lessons_map.pointers(topic)}")
        for number in topic.get('lessons', []):
            print(f"   {index.get(number, f'§{number} (no index entry)')}")
        print()
    return 0


if __name__ == '__main__':
    sys.exit(main())

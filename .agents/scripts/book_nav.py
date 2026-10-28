#!/usr/bin/env python3
"""Keep a book-contents block in every chapter of the mdBook under book/src/.

  book_nav.py write [--book DIR]   (re)generate the block in every chapter
  book_nav.py check [--book DIR]   fail if a chapter's block is missing or stale

mdBook draws a sidebar from SUMMARY.md, but a chapter read as plain Markdown
(GitHub, an editor, an agent's file view) has none. The block below the first
heading is that sidebar as text: the chapters in SUMMARY.md order under their
part headings, the current one in bold, and previous/next links. It is
generated from SUMMARY.md, so reordering the book is one edit there plus
`write`; `check` (run by preflight) catches a chapter left behind.

In the rendered book the sidebar already does this job, so the block is a
`<details class="book-nav">` that book/hide-book-nav.css hides.

Pure stdlib. Fixture tests: .agents/scripts/test_book_nav.py.
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
START = "<!-- book-nav: generated from SUMMARY.md by `just agent book-nav write`; do not edit -->"
END = "<!-- /book-nav -->"
BLOCK = re.compile(re.escape(START) + r".*?" + re.escape(END) + r"\n?", re.S)
ENTRY = re.compile(r"^\s*[-*]?\s*\[([^\]]+)\]\(([^)#\s]+\.md)\)\s*$")
PART = re.compile(r"^#\s+(.+?)\s*$")


def parse_summary(text):
    """-> (items, numbers): items is [('part', title) | ('page', title, file)]
    in order; numbers maps file -> the number mdBook shows (prefix pages have
    none)."""
    items, numbers, n, seen_part = [], {}, 0, False
    for line in text.splitlines():
        m = PART.match(line)
        if m:
            if m.group(1).lower() != "summary":
                items.append(("part", m.group(1)))
                seen_part = True
            continue
        m = ENTRY.match(line)
        if m:
            items.append(("page", m.group(1), m.group(2)))
            if seen_part:
                n += 1
                numbers[m.group(2)] = n
    return items, numbers


def block_for(current, items, numbers):
    pages = [i for i in items if i[0] == "page"]
    names = [p[2] for p in pages]
    title = next(p[1] for p in pages if p[2] == current)
    lines = [START, '<details class="book-nav">',
             f"<summary>Book contents (you are on: {title})</summary>", ""]
    group = []

    def flush():
        if group:
            lines.extend(group)
            lines.append("")
            group.clear()

    for it in items:
        if it[0] == "part":
            flush()
            lines.append(f"**{it[1]}**")
            lines.append("")
            continue
        _, t, f = it
        num = f"{numbers[f]}. " if f in numbers else ""
        label = f"**{t}** (this page)" if f == current else f"[{t}]({f})"
        group.append(f"{num}{label}")
    flush()
    i = names.index(current)
    nav = []
    if i > 0:
        nav.append(f"← [{pages[i - 1][1]}]({names[i - 1]})")
    if i < len(pages) - 1:
        nav.append(f"[{pages[i + 1][1]}]({names[i + 1]}) →")
    if nav:
        lines.append(" · ".join(nav))
        lines.append("")
    lines.append("</details>")
    lines.append(END)
    return "\n".join(lines) + "\n"


def apply(text, block):
    """Insert or replace the block just after the first heading line."""
    text = BLOCK.sub("", text, count=1)
    lines = text.split("\n")
    in_fence = False
    for idx, line in enumerate(lines):
        if line.startswith("```"):
            in_fence = not in_fence
        if not in_fence and re.match(r"^#\s+\S", line):
            rest = "\n".join(lines[idx + 1:]).lstrip("\n")
            return "\n".join(lines[:idx + 1]) + "\n\n" + block + "\n" + rest
    return block + "\n" + text


def chapters(src):
    summary = src / "SUMMARY.md"
    items, numbers = parse_summary(summary.read_text())
    return items, numbers, [i[2] for i in items if i[0] == "page"]


def check(src):
    items, numbers, files = chapters(src)
    findings = []
    for f in files:
        p = src / f
        if not p.exists():
            continue
        text = p.read_text()
        want = apply(text, block_for(f, items, numbers))
        if text != want:
            has = BLOCK.search(text) is not None
            findings.append(f"nav      {f}: book-contents block is "
                            f"{'stale' if has else 'missing'} -- run `just agent book-nav write`")
    return findings


def write(src):
    items, numbers, files = chapters(src)
    changed = []
    for f in files:
        p = src / f
        if not p.exists():
            continue
        text = p.read_text()
        new = apply(text, block_for(f, items, numbers))
        if new != text:
            p.write_text(new)
            changed.append(f)
    return changed


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("cmd", choices=("write", "check"))
    ap.add_argument("--book", default=str(ROOT / "book"))
    a = ap.parse_args(argv)
    src = Path(a.book) / "src"
    if not (src / "SUMMARY.md").exists():
        print(f"book_nav: no {src}/SUMMARY.md", file=sys.stderr)
        return 2
    if a.cmd == "write":
        changed = write(src)
        print(f"book_nav: updated {len(changed)} chapter(s)" if changed else "book_nav: already current")
        return 0
    findings = check(src)
    for f in findings:
        print(f)
    print(f"book_nav: {len(findings)} finding(s)" if findings else "book_nav: no findings")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())

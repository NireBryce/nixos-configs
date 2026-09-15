#!/usr/bin/env python3
"""Rank wiki/ sections that look like resolved-incident narrative -- the
kind styleguide.md's "Directory hierarchy" section says belongs in a
`<name>-history.md` companion rather than on the live page.

Why this exists as a script at all: the pattern was created in one pass
(`68b99813`, 2026-09-02, six category pages) and extracted into exactly once
since (`5cdd8b2b`, 2026-09-06, when homelab/backup-runbook.md was rewritten).
Every other commit touching a `-history.md` is incidental -- the `+2 lines`
on five of the six is the wiki-wide `_Last modified:_` commit. Nothing
routes to the pattern on a cadence, so pages accumulate and nobody is asked.
Issue #288. Skill `wiki-history-sweep` is the procedure; this is only its
first step.

**Reporting only. Never fails, never writes.** Same shape and same reasoning
as `wiki_churn.py` and `wiki_stale_refs.py`, and for a sharper reason than
either: what actually qualifies is a judgement no regex can make. The
styleguide's own test is

    does understanding the CURRENT setting require this paragraph,
    or only understanding how it came to be that way?

and only the second kind moves. A section can be wall-to-wall past tense and
dates and still be mechanism explained through its discovery, which this
repo's "checked, not assumed" style produces constantly and which
`68b99813` deliberately kept every instance of. Three worked examples of
exactly that, all confirmed by hand 2026-09-11 and all scored here as
candidates anyway:

  - categories/landing.md's "Two things that could have gone quietly wrong,
    and didn't" -- reads historical, is not: both are confirmed-live facts
    and the section states the fix if either changes.
  - categories/shell-config/blesh.md's `read: not a valid identifier` bug --
    diagnosis narrative, but the upstream bug is still open.
  - categories/system.md's "Containers vs. virtualization -- no longer filed
    here" -- the page says outright the trap is live and this is where
    someone remembering the old location will look.

So expect the list to be mostly wrong. It is a reading list, not a work
queue: the value is that the question gets asked at all.

Usage:
    just wiki-history-candidates              # everything scoring > 0
    just wiki-history-candidates --min 3      # only stronger hits
    just wiki-history-candidates --page wiki/categories/reverse-proxy.md
"""
import argparse
import pathlib
import re
import sys

# Phrases that mark a section as being ABOUT something finished, weighted by
# how rarely they show up in prose describing a live setting. A self-applied
# "(historical)" label is near-conclusive; a bare date is nearly worthless on
# its own in a wiki whose house style dates every verified claim.
MARKERS = [
    (5, 'self-labelled historical', re.compile(r'\(historical\)', re.I)),
    (4, 'retired', re.compile(r'\bretired\b', re.I)),
    (4, 'superseded', re.compile(r'\bsuperseded\b', re.I)),
    (3, 'no longer X', re.compile(
        r'\bno longer (?:in use|used|needed|applies|exists)\b', re.I)),
    (2, 'used to', re.compile(r'\bused to\b', re.I)),
    (2, 'since removed', re.compile(r'\bsince (?:removed|deleted|dropped)\b', re.I)),
    (2, 'was removed', re.compile(r'\bwas removed\b', re.I)),
    (2, 'the original plan', re.compile(
        r'\bthe original (?:plan|design|constraint|shape)\b', re.I)),
    (1, 'now has its own', re.compile(r'\bnow (?:has|have|its own|each)\b', re.I)),
    (1, 'dated', re.compile(r'20\d{2}-\d{2}-\d{2}')),
]

# A heading that says so outright. These bypass KEEPERS entirely: a section
# titled "... (historical)" or "3. Done -- ..." is the page telling you what
# it is, and a "confirmed live" inside it is describing the finished work,
# not a live setting. Without this the two cancelled out and a Done item
# scored BELOW a still-pending one (hit while writing this, on
# homelab/pending-setup.md items 3 and 4).
CONCLUSIVE = [
    (6, 'heading: historical', re.compile(r'\(historical\)', re.I)),
    (6, 'heading: retired', re.compile(r'^\s*retired\b', re.I)),
    (6, 'heading: Done', re.compile(r'^\s*\d+\.\s*Done\b', re.I)),
    # Also a heading that only says so at the END -- pending-setup.md item 6
    # is "6. Housekeeping on cube: one scratch directory left over -- done",
    # which the leading-Done pattern above misses entirely (it scored 1).
    (6, 'heading: ends done', re.compile(r'[-—:,]\s*done\.?\s*$', re.I)),
]

# Counter-markers: phrasing that says the paragraph still justifies a live
# setting. These SUBTRACT, because the conservative rule is keep-by-default.
KEEPERS = [
    (3, 'still applies', re.compile(
        r'\bstill (?:live|applies|true|the case|relevant)\b', re.I)),
    (3, 'confirmed live', re.compile(r'\bconfirmed live\b', re.I)),
    (2, 'the fix is', re.compile(r'\bthe fix is\b', re.I)),
    (2, 'still open', re.compile(r'\bstill open\b', re.I)),
    (2, 'currently', re.compile(r'\bcurrently\b', re.I)),
]

SKIP = re.compile(r'-for-agents\.md$|-history\.md$|lessons-learned|^wiki/history\.md$')
HEADING = re.compile(r'^(##+) (.+)$', re.M)


def sections(text):
    """(heading, body, start_line) per `##`-or-deeper section. The preamble
    before the first heading is not a section -- nothing above the first
    `##` is ever a candidate to move."""
    marks = list(HEADING.finditer(text))
    for i, m in enumerate(marks):
        end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
        yield m.group(2).strip(), text[m.start():end], text[:m.start()].count('\n') + 1


def score(heading, body):
    hits, total = [], 0
    for weight, label, rx in MARKERS:
        n = len(rx.findall(body))
        if n:
            total += weight * min(n, 3)
            hits.append(label)
        if rx.search(heading):
            total += weight
    conclusive = False
    for weight, label, rx in CONCLUSIVE:
        if rx.search(heading):
            total += weight
            hits.append(label)
            conclusive = True
    if not conclusive:
        for weight, label, rx in KEEPERS:
            if rx.search(body):
                total -= weight
                hits.append('-' + label)
    return max(total, 0), hits


def destination(path, root):
    """Where a section on `path` would go, per the one-companion-per-CATEGORY
    rule `5cdd8b2b` set: a usage-tier page drains into its category's history
    file, not its own. Returns None when that rule doesn't resolve -- which
    is a finding, not an error (issue #288: pending-setup.md spans four
    categories and has no single destination)."""
    if path.parent.name == 'categories':
        cand = path.with_name(path.stem + '-history.md')
        return cand, cand.exists()
    return None, False


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--min', type=int, default=1, help='minimum score to list')
    ap.add_argument('--page', help='only this page')
    args = ap.parse_args()

    root = pathlib.Path(__file__).resolve().parents[2]
    pages = ([root / args.page] if args.page
             else sorted(p for p in (root / 'wiki').rglob('*.md')
                         if not SKIP.search(p.relative_to(root).as_posix())))

    rows = []
    for p in pages:
        if not p.exists():
            print(f"no such page: {p}", file=sys.stderr)
            return 2
        text = p.read_text()
        for heading, body, line in sections(text):
            if heading in ('Contents', 'See also'):
                continue
            s, hits = score(heading, body)
            if s >= args.min:
                rows.append((s, p.relative_to(root), line, heading,
                             body.count('\n'), hits))

    rows.sort(key=lambda r: -r[0])
    if not rows:
        print("no candidate sections")
        return 0

    for s, rel, line, heading, lines, hits in rows:
        dest, exists = destination(rel, root)
        where = (f"-> {dest.name}{'' if exists else ' (would be new)'}"
                 if dest else "-> NO SINGLE DESTINATION, see skill step 4")
        print(f"[{s:>2}] {rel}:{line}  ({lines} lines)  {where}")
        print(f"     {heading}")
        print(f"     markers: {', '.join(sorted(set(hits))) or '-'}")
    print(f"\n{len(rows)} candidate sections. Reporting only -- most of these "
          f"should NOT move.\nRead the script's docstring and skill "
          f"`wiki-history-sweep` before touching any of them.")
    return 0


if __name__ == '__main__':
    sys.exit(main())

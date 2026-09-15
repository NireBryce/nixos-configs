#!/usr/bin/env python3
"""Report prose restated across this repo's agent-facing docs.

The repo's compression rule (trim-docs, styleguide "index over
restatement") is one pointer per fact: AGENTS.md carries the always-loaded
summary, skills the on-invocation detail, wiki/ the deep account, and no
fact should be stated twice in prose across those layers -- a restatement
is a future stale claim (wiki-sync then has two copies to fix, or worse,
one). This tool is the mechanical half: word-8-gram overlap between
AGENTS.md, every .agents/skills/**/*.md, and every wiki/**/*.md.

Report-only, never fails -- like wiki_churn.py and wiki_stale_refs.py,
most hits need a human judgement call: overlap between
wiki/lessons-learned.md and its wiki/lessons-learned/ articles is by
design (one-line summary + link, full account next door), and a shared
table of ports or a quoted command may be the fact's one true home.
Read the spans, decide which copy dies.

Excluded from matching by design: fenced code blocks (commands legitimately
repeat) and H1 lines (article titles deliberately repeat their § heading).

Ranked separately, not excluded: a `<page>.md` / `<page>-for-agents.md`
pair (wiki/styleguide.md, "Two audiences per page"). That overlap is the
whole point of the split -- the sibling restates its source on purpose,
densely -- so counting it as a finding would bury every real one; all 19
pairs outranked the top genuine hit when the split landed. They are held
back behind --siblings instead of dropped, because the ONE thing worth
seeing there is a sibling whose overlap has grown large enough that it is
turning back into a copy of the page, which is exactly what
`check_wiki.py siblings`' word budget is watching for from the other side.

Usage:
    check_restatement.py [--min-words N] [--top N] [--all] [--siblings]

    --min-words  minimum overlapping words for a pair to be reported (12)
    --top        how many pairs to show (15; most-overlapping first)
    --all        show every pair, not just the top
    --siblings   rank the by-design -for-agents pairs in too
"""

import argparse
import collections
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
NGRAM = 8
FENCE = re.compile(r"^(```|~~~)")
HEADING = re.compile(r"^#+\s")
CONTENTS = re.compile(r"^##\s+Contents\s*$")
WORD = re.compile(r"[a-z0-9_]['a-z0-9_.-]*")


SIBLING_SUFFIX = "-for-agents.md"


def is_sibling_pair(a, b):
    """True when these two paths are a `<page>.md` / `<page>-for-agents.md`
    pair. Only the pair itself -- a sibling against some OTHER page's source
    is an ordinary hit and stays ranked."""
    for x, y in ((a, b), (b, a)):
        if x.endswith(SIBLING_SUFFIX) and x[: -len(SIBLING_SUFFIX)] + ".md" == y:
            return True
    return False


def doc_paths():
    yield ROOT / "AGENTS.md"
    yield from sorted((ROOT / ".agents" / "skills").rglob("*.md"))
    yield from sorted((ROOT / "wiki").rglob("*.md"))


def normalize(path):
    """([(word, lineno)], [word]) -- words tagged with their source line,
    with fenced blocks, H1 lines (article titles repeat their § heading by
    design), and ## Contents blocks (navigation, not prose) dropped so
    by-design repeats don't register as restatement."""
    tagged = []
    fence = False
    in_contents = False
    for lineno, line in enumerate(path.read_text().splitlines(), 1):
        if FENCE.match(line):
            fence = not fence
            continue
        if fence:
            continue
        if CONTENTS.match(line):
            in_contents = True
            continue
        if in_contents:
            if HEADING.match(line):
                in_contents = False
            else:
                continue
        if line.startswith("# "):
            continue
        for word in WORD.findall(line.lower()):
            tagged.append((word, lineno))
    return tagged, [w for w, _ in tagged]


def spans_from_shared(shared_pairs):
    """Merge (pos_a, pos_b) shingle hits where both sides advance by one
    word into contiguous spans; returns [(start_a, start_b, shingles)]."""
    spans = []
    for pa, pb in sorted(shared_pairs):
        if spans and pa == spans[-1][0] + 1 and pb == spans[-1][1] + 1:
            spans[-1][2] += 1
        else:
            spans.append([pa, pb, 1])
    return spans


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--min-words", type=int, default=12)
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--siblings", action="store_true")
    args = ap.parse_args()

    files = {}
    for path in doc_paths():
        if path.is_file():
            files[path.relative_to(ROOT).as_posix()] = normalize(path)

    # shingle -> {file: [start positions]}
    index = collections.defaultdict(lambda: collections.defaultdict(list))
    for name, (tagged, _) in files.items():
        words = [w for w, _ in tagged]
        for i in range(len(words) - NGRAM + 1):
            index[tuple(words[i : i + NGRAM])][name].append(i)

    # pair -> list of (pos_a, pos_b) shared shingles
    pairs = collections.defaultdict(list)
    for positions in index.values():
        names = sorted(positions)
        for i, a in enumerate(names):
            for b in names[i + 1 :]:
                for pa in positions[a]:
                    for pb in positions[b]:
                        pairs[(a, b)].append((pa, pb))

    def rel(pair):
        a, b = pair
        spans = spans_from_shared(pairs[pair])
        words = sum(n + NGRAM - 1 for _, _, n in spans)
        return words, spans

    hits, sibling_hits = [], []
    for pair in pairs:
        total, spans = rel(pair)
        if total < args.min_words:
            continue
        entry = (total, pair, spans)
        if not args.siblings and is_sibling_pair(*pair):
            sibling_hits.append(entry)
        else:
            hits.append(entry)
    hits.sort(reverse=True)
    sibling_hits.sort(reverse=True)

    shown = hits if args.all else hits[: args.top]
    if not shown:
        print(f"no pair shares {args.min_words}+ words of prose")
        return

    print(
        f"{len(hits)} pair(s) share {args.min_words}+ words "
        f"(shingle={NGRAM}; lessons-learned.md ↔ its articles is by design)"
    )
    if sibling_hits:
        worst = sibling_hits[0]
        print(
            f"  + {len(sibling_hits)} -for-agents sibling pair(s) held back "
            f"as by-design (--siblings to rank them in); most-overlapping "
            f"is {worst[1][0]} ↔ {worst[1][1]} at ~{worst[0]}w"
        )
    for total, (a, b), spans in shown:
        print(f"\n{a}  ↔  {b}  — ~{total}w in {len(spans)} span(s)")
        words_a, lines_a = files[a][1], files[a][0]
        for pa, pb, n in sorted(spans, key=lambda s: -(s[2] + NGRAM - 1))[:3]:
            length = n + NGRAM - 1
            text = " ".join(words_a[pa : pa + length])
            print(f"  {length:>3}w  {a}:{lines_a[pa][1]}  {b}:{files[b][0][pb][1]}")
            print(f"       “{text[:110]}”")


if __name__ == "__main__":
    main()

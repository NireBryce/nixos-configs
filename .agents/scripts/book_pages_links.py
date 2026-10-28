#!/usr/bin/env python3
"""Make the book's repo-relative links work on GitHub Pages.

  book_pages_links.py <book-dir> [--base URL]

The chapters link into the repo (`](../../wiki/foo.md)`), which resolves when
the source is browsed on GitHub and 404s once mdBook has built the chapters
into a site root. This rewrites those links in place, in every .md under
<book-dir>, to absolute blob URLs on --base. Run it on a throwaway copy
(.github/workflows/book.yml does), never on the checkout: the source keeps
relative links so `book_lint.py` and repo browsing see real files.

Only `](../../...)` is rewritten: chapters sit flat in book/src, so two levels
up is the repo root. Other links are left alone. Pure stdlib; fixture test:
.agents/scripts/test_book_pages_links.py.
"""
import re
import sys
from pathlib import Path

BASE = "https://github.com/NireBryce/nixos-configs/blob/experimental/"
LINK = re.compile(r"\]\(\.\./\.\./([^)\s]*)\)")


def rewrite(text, base=BASE):
    return LINK.sub(lambda m: f"]({base}{m.group(1)})", text)


def main(argv):
    base = BASE
    if "--base" in argv:
        i = argv.index("--base")
        base = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    if len(argv) != 1:
        print(__doc__)
        return 2
    changed = 0
    for p in Path(argv[0]).rglob("*.md"):
        old = p.read_text()
        new = rewrite(old, base)
        if new != old:
            p.write_text(new)
            changed += 1
    print(f"book_pages_links: rewrote links in {changed} file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

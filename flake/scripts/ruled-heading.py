#!/usr/bin/env python3
"""Print a ruled section heading for a comment, in the repo's house style:

    # ── history ─────────────────────────────────────────────────────────────────

    ruled-heading.py history                  # the line above
    ruled-heading.py --indent 8 "Home Manager"
    ruled-heading.py --prefix '//' shared     # another comment leader

The rule pads to 78 characters, indent included. 78 is what most top-level
headings in the tree already are (every `# ── history ──` one); hand-drawn
ones drift a character or two past it. Indented headings (inside a `let`
or attrset) vary from 80 to 89 with no pattern, so there was nothing to
match -- 78 total keeps them inside the same right edge. A title too long
to fit still gets the `── ` lead and one trailing `─`, never a truncation.

history-line.sh finds the history heading by its shape (`#`, optional run
of `─`, then "history"), so output of this script is always found by it.
"""

import argparse

RULE = "─"


def heading(title: str, width: int = 78, indent: int = 0, prefix: str = "#") -> str:
    line = f"{' ' * indent}{prefix} {RULE * 2} {title} "
    return line + RULE * max(1, width - len(line))


def main() -> None:
    parser = argparse.ArgumentParser(description="Print a ruled comment heading.")
    parser.add_argument("title", nargs="+", help="heading text (words are joined by spaces)")
    parser.add_argument("--width", type=int, default=78, help="total line width (default 78)")
    parser.add_argument("--indent", type=int, default=0, help="leading spaces (default 0)")
    parser.add_argument("--prefix", default="#", help="comment leader (default '#')")
    args = parser.parse_args()
    print(heading(" ".join(args.title), args.width, args.indent, args.prefix))


if __name__ == "__main__":
    main()

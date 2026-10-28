#!/usr/bin/env python3
"""Turn a built mdBook into one self-contained HTML file.

  book_render.py <mdbook-output-dir> <destination.html>

mdBook's `print.html` holds every chapter on one page but pulls its styling
from sibling files and its behavior from scripts, so it renders unstyled
anywhere but the output directory. This inlines the stylesheets, drops the
scripts and the navigation chrome, and writes one file that can be sent or
opened on its own. Build first: `mdbook build book -d <dir>`.

Pure stdlib. Fixture test: .agents/scripts/test_book_lint.py.
"""
import re
import sys
from pathlib import Path

CSS_STEMS = ("css/variables", "css/general", "css/chrome", "css/print", "highlight")
LAYOUT = ("body{max-width:860px;margin:2rem auto;padding:0 16px}"
          ".sidebar,#sidebar,.menu-bar,#menu-bar,.nav-chapters,nav{display:none!important}"
          ".page-wrapper{margin:0!important;padding:0!important}")


def render(outdir):
    outdir = Path(outdir)
    printed = outdir / "print.html"
    if not printed.is_file():
        raise SystemExit(f"book_render: no print.html in {outdir}; run `mdbook build book -d {outdir}` first")
    css = ""
    for stem in CSS_STEMS:
        parent = (outdir / stem).parent
        for sheet in sorted(parent.glob(Path(stem).name + "-*.css")) + sorted(parent.glob(Path(stem).name + ".css")):
            css += sheet.read_text() + "\n"
    html = printed.read_text()
    html = re.sub(r"<link[^>]*rel=\"stylesheet\"[^>]*>", "", html)
    html = re.sub(r"<script.*?</script>", "", html, flags=re.S)
    return html.replace("</head>", f"<style>{css}\n{LAYOUT}</style></head>", 1)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 2:
        print(__doc__)
        return 2
    Path(argv[1]).write_text(render(argv[0]))
    print(f"book_render: wrote {argv[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

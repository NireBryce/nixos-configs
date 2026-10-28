#!/usr/bin/env python3
"""Mechanical checks of the mdBook under book/src/: what a reader can be
misled by without any fact being wrong.

  book_lint.py check [--book DIR]   links, anchors, SUMMARY, volatile facts
  book_lint.py prose [--book DIR]   long paragraphs and sentences, filler,
                                    vague openers (reports, never fails)

`check` fails (exit 1) on:
  link      a relative link whose target file does not exist
  anchor    a `file.md#fragment` whose fragment is no heading slug in that file
  summary   a chapter under src/ that SUMMARY.md does not list, or a SUMMARY
            entry with no file
  volatile  a fact the book's maintainability rule keeps out of prose: an
            ISO date, or a count of hosts, files, modules, categories, hooks,
            skills, recipes, lessons or commits ("three hooks", "12 files").
            Point at the file or command that answers it instead. "two files"
            and "two modules" pass: they illustrate a rule ("if two files
            share a name") rather than count what the repo holds.
Code fences and inline code are not scanned. A line containing
`book-lint: ignore` (in a comment) is skipped, for the rare count that is the
rule itself.

Slugs follow mdBook's: lower-case, punctuation dropped, spaces to hyphens.
`prose` is for the human pass: it prints the longest paragraphs and sentences
and counts, so a rewrite can start where the text is hardest to read.

Pure stdlib. Fixture tests: .agents/scripts/test_book_lint.py.
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NUMBERS = (r"\d+|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|"
           r"thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|dozens?")
NOUNS = r"hosts?|machines|files|modules|categories|hooks|skills|recipes|lessons|commits"
COUNT = re.compile(rf"\b({NUMBERS})\s+({NOUNS})\b", re.I)
DATE = re.compile(r"\b20\d\d-\d\d-\d\d\b")
FILLER = re.compile(
    r"\b(in order to|it is worth|worth noting|note that|simply|basically|essentially|"
    r"of course|obviously|clearly|importantly|in fact|that said|in other words|"
    r"a number of|a lot of)\b", re.I)
VAGUE_OPEN = re.compile(r"^(This|That|It|These|Those|They|There)\b")
LINK = re.compile(r"\]\(([^)\s]+)\)")


def strip_code(text):
    """Blank out fenced blocks and inline code, keeping line numbers."""
    def blank(m):
        return re.sub(r"[^\n]", " ", m.group(0))
    text = re.sub(r"```.*?```", blank, text, flags=re.S)
    return re.sub(r"`[^`\n]*`", blank, text)


def slug(heading):
    h = re.sub(r"[`*_]", "", heading).strip().lower()
    h = re.sub(r"[^\w\- ]", "", h)
    return h.replace(" ", "-")


def headings(path):
    out = set()
    for line in strip_code_keep_headings(path.read_text()).splitlines():
        m = re.match(r"^#{1,6}\s+(.*?)\s*#*$", line)
        if m:
            out.add(slug(m.group(1)))
    return out


def strip_code_keep_headings(text):
    return re.sub(r"```.*?```", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)


def chapters(src):
    return sorted(p for p in src.glob("*.md") if p.name != "SUMMARY.md")


def check(src):
    findings = []
    summary = (src / "SUMMARY.md").read_text() if (src / "SUMMARY.md").exists() else ""
    listed = set(re.findall(r"\]\(([^)#\s]+\.md)\)", summary))
    for name in sorted(listed):
        if not (src / name).exists():
            findings.append(f"summary  SUMMARY.md lists {name}, which does not exist")
    for p in chapters(src):
        if p.name not in listed:
            findings.append(f"summary  {p.name} is not listed in SUMMARY.md")
    for p in chapters(src):
        text = p.read_text()
        raw_lines = text.splitlines()
        scan = strip_code(text).splitlines()
        for n, (raw, line) in enumerate(zip(raw_lines, scan), 1):
            if "book-lint: ignore" in raw:
                continue
            for m in LINK.finditer(line):
                target = m.group(1)
                if target.startswith(("http:", "https:", "mailto:")):
                    continue
                path, _, frag = target.partition("#")
                if not path:
                    if frag and slug(frag) not in headings(p) and frag not in headings(p):
                        findings.append(f"anchor   {p.name}:{n} #{frag} matches no heading here")
                    continue
                dest = (p.parent / path).resolve()
                if not dest.exists():
                    findings.append(f"link     {p.name}:{n} {target} does not exist")
                elif frag and dest.suffix == ".md" and frag not in headings(dest):
                    findings.append(f"anchor   {p.name}:{n} {target}: no heading with that slug")
            for m in DATE.finditer(line):
                findings.append(f"volatile {p.name}:{n} date {m.group(0)}: say what changed, not when")
            for m in COUNT.finditer(line):
                if m.group(1).lower() == "two" and m.group(2).lower() in ("files", "modules"):
                    continue
                findings.append(f"volatile {p.name}:{n} count \"{m.group(0)}\": point at the file or command that lists them")
    return findings


def prose(src, top=8):
    paras, sents, filler, vague = [], [], {}, {}
    for p in chapters(src):
        body = strip_code(p.read_text())
        for para in re.split(r"\n\s*\n", body):
            para = para.strip()
            if not para or para.startswith(("|", "#", ">", "<!--")) or re.match(r"^(\d+\.|[-*])\s", para):
                continue
            flat = " ".join(para.split())
            paras.append((len(flat.split()), p.name, flat[:70]))
            for s in re.split(r"(?<=[.!?])\s+", flat):
                sents.append((len(s.split()), p.name, s[:80]))
                if VAGUE_OPEN.match(s):
                    vague[p.name] = vague.get(p.name, 0) + 1
            for m in FILLER.finditer(flat):
                filler[(p.name, m.group(1).lower())] = filler.get((p.name, m.group(1).lower()), 0) + 1
    print(f"{len(chapters(src))} chapters")
    print(f"\nlongest paragraphs (words):")
    for w, f, t in sorted(paras, reverse=True)[:top]:
        print(f"  {w:4} {f}: {t}")
    print(f"\nlongest sentences (words):")
    for w, f, t in sorted(sents, reverse=True)[:top]:
        print(f"  {w:4} {f}: {t}")
    print("\nfiller phrases:", dict(sorted(filler.items(), key=lambda kv: -kv[1])[:top]) or "none")
    print("sentences opening with This/It/That/These/There, by chapter:", dict(sorted(vague.items(), key=lambda kv: -kv[1])) or "none")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("cmd", choices=("check", "prose"))
    ap.add_argument("--book", default=str(ROOT / "book"))
    a = ap.parse_args(argv)
    src = Path(a.book) / "src"
    if not src.is_dir():
        print(f"book_lint: no {src}", file=sys.stderr)
        return 2
    if a.cmd == "prose":
        return prose(src)
    findings = check(src)
    for f in findings:
        print(f)
    print(f"book_lint: {len(findings)} finding(s)" if findings else "book_lint: no findings")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())

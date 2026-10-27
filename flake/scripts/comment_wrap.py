#!/usr/bin/env python3
"""Re-flow pure `#` comment blocks in the Nix modules to the house column.

The rule (wiki/module-style-guide.md, "Comment width"): a comment line may
reach 80 columns plus the line's own indentation -- a comment indented four
spaces wraps at 84 -- so the text after `# ` keeps one constant width
wherever the module nests it. That is the shape the tree already used
before comment inserts landed past the wrap the surrounding block used
(commit 9d688b3a put several `# summary:` lines and folded claims in over
it); this is the checker and fixer for the rule, and skill `comment-wrap`
the procedure around it.

Only lines that are nothing but a comment are touched. A `#` inside a
`''` or `"` string is shell or config text, not a Nix comment --
wiki/module-style-guide.md's documented trap, fourteen lines of maintenance
notes once shipped into `~/.zshrc` that way -- so the scanner lexes strings
and the `${ ... }` interpolations inside them and neither reports nor
rewrites inside one. Trailing comments after code are code-coupled and
also out of scope.

Rewrapping joins a paragraph and fills it again, which is only safe on
unambiguous prose. A paragraph is autofixable ("prose") when every line
reads `# <text>` with a word-like first character and nothing code-shaped
outside backtick spans: no `${`, `=`, braces, redirects or flag-like
tokens, and no token so long the rewrapped lines could not hold it.
Exempt outright, never reported: URL lines (a URL must not break),
aligned `# ... # ...` tables, banner/decoration lines, commented-out
code and shell snippets (including command-led aligned continuations),
single tokens wider than any wrapped line could hold, and anything
inside strings. Reported for hand work instead of autofixed: a
`# summary:` line that is itself over the limit (one line by rule, so
the fix is tightening the text, not wrapping it -- the rest of that
lead paragraph refills mechanically around it), bullets, prose aligned
continuations, odd first characters, and a backtick span opened on one
line and closed on another.

Usage:
    comment_wrap.py [--check] [--fix] [--diff] [--limit N] [--all] [PATH ...]

Default PATH is the module tree next to this script (flake/modules).
With no mode this is --check: report and exit 1 on anything over the
limit. --fix rewrites what it safely can in place; --diff prints that
fix as a unified diff without writing. Both report what remains after
the fix, and exit 1 only on what remains -- the hand-work list -- so
`--fix` landing green means the autofix left nothing over the limit.
--all also lists the exempt lines. Exit 0 clean, 1 findings remaining,
2 on bad usage or an unreadable path. Pure stdlib; fixture-tested by
flake/scripts/tests/test_comment_wrap.py (`just comment-wrap-test`, in
preflight).
"""
import argparse
import difflib
import re
import sys
from pathlib import Path

LIMIT = 80

CODE, DQ, SS = 0, 1, 2

URL_RE = re.compile(r"https?://")
# A second ` # ` inside the text: an aligned `# ... # ...` table row.
TABLE_RE = re.compile(r"\s#(?:\s|$)")
# Decoration: a pure dash/hash rule, or a rule padded around a label
# (`── this machine ─────`), in either ASCII or box-drawing/em dashes.
BANNER_RE = re.compile(
    r"^[#=\-*~=─—]{2,}\s.*\s[#=\-*~=─—]{2,}$|^[#=\-*~=─—]{2,}$")
SUMMARY_RE = re.compile(r"^(?:package )?summary:")
BULLET_RE = re.compile(r"^(?:[-*+]|\d+[.)])\s")
BAD_CHARS_RE = re.compile(r"[${}=<>|\\^@]")
FIRST_CHAR_RE = re.compile(r"^[A-Za-z0-9`\"'(.~/]")
FLAG_TOKEN_RE = re.compile(r"^-[-a-zA-Z_]")
BACKTICK_SPAN_RE = re.compile(r"`[^`]*`")
# First words that make a line commented-out shell, not prose about it.
CMD_WORDS = {
    "sudo", "systemctl", "alias", "export", "nix", "nix-shell", "nix-build",
    "nix-instantiate", "nixos-option", "jq", "rsync", "printf", "unset",
    "mkdir", "xargs", "chmod", "chown", "exec", "eval", "function",
    "declare", "typeset", "local",
}


def comment_indents(text):
    """Map line number -> indent for every pure `#` comment line.

    Lexes enough Nix to know which `#` start comments: strings (`"`,
    `''`, with their escape forms) and `${ ... }` interpolations into
    them, including braces and comments inside an interpolation. A line
    counts only when its first non-whitespace character is a `#` while
    at top level, outside every interpolation.
    """
    found = {}
    state = CODE
    interp = []  # string state to restore per open `${`
    depth = 0    # open `{` inside the innermost interpolation
    for lineno, line in enumerate(text.split("\n")):
        i = 0
        while i < len(line) and line[i] in " \t":
            i += 1
        if state == CODE and not interp and i < len(line) and line[i] == "#":
            found[lineno] = i
            continue  # the comment runs to end of line; nothing to lex
        while i < len(line):
            c = line[i]
            if state == CODE:
                if c == "#":
                    break  # trailing comment, rest of line inert
                if c == '"':
                    state = DQ
                elif line[i:i + 2] == "''":
                    state = SS
                    i += 1
                elif line[i:i + 2] == "/*":
                    end = line.find("*/", i + 2)
                    i = len(line) if end < 0 else end + 1
                elif interp and c == "{":
                    depth += 1
                elif interp and c == "}":
                    depth -= 1
                    if depth <= 0:
                        depth = 0
                        state = interp.pop()
            elif state == DQ:
                if c == "\\":
                    i += 1
                elif line[i:i + 2] == "${":
                    interp.append(DQ)
                    depth = 1
                    state = CODE
                    i += 1
                elif c == '"':
                    state = CODE
            else:  # SS
                if line[i:i + 2] == "''":
                    nxt = line[i + 2:i + 3]
                    if nxt == "'":                 # ''' is a literal ''
                        i += 3
                        continue
                    if line[i + 2:i + 4] == "${":  # ''${ is a literal ${
                        i += 4
                        continue
                    if nxt == "\\":                # ''\x escape
                        i += 4
                        continue
                    state = CODE                   # close the string
                    i += 2
                    continue
                if line[i:i + 2] == "${":
                    interp.append(SS)
                    depth = 1
                    state = CODE
                    i += 1
            i += 1
    return found


def content_of(line, indent):
    """A pure comment line's text after `#`, minus one joining space."""
    rest = line[indent + 1:]
    return rest[1:] if rest.startswith(" ") else rest


def paragraphs(lines, comments):
    """Group pure comment lines into (indent, [(lineno, content), ...]).

    A paragraph ends at a bare `#` line, a banner/decoration line (its
    own unit, never merged), a non-comment line, an indent change, a
    bullet item (its own unit, never merged with neighbours), or a line
    whose content carries extra leading whitespace (aligned
    continuation, also never merged).
    """
    out = []
    cur_indent = None
    cur = []
    prev_lineno = None
    for lineno, indent in sorted(comments.items()):
        content = content_of(lines[lineno], indent)
        bare = content.strip() == ""
        banner = BANNER_RE.match(content) is not None
        starts_item = BULLET_RE.match(content) is not None
        indented = content.startswith((" ", "\t"))
        adjacent = prev_lineno is not None and lineno == prev_lineno + 1
        if cur and (bare or banner or not adjacent or indent != cur_indent
                    or starts_item or indented):
            out.append((cur_indent, cur))
            cur = []
        prev_lineno = lineno
        if bare or banner:
            cur_indent = None
            continue
        if not cur:
            cur_indent = indent
        cur.append((lineno, content))
    if cur:
        out.append((cur_indent, cur))
    return out


def word_like(content):
    """Word-like enough to join and refill: `# text` with a word-like
    first character, or a continuation led by the house em-dash `-- `."""
    return bool(FIRST_CHAR_RE.match(content)) or content.startswith("-- ")


def classify(para_indent, para, limit, over):
    """Sort a paragraph: `prose` (autofixable), an exempt class, or a
    hand class. Returns (class, detail). `over` is the paragraph's
    over-limit line numbers, computed by the caller."""
    texts = [content for _, content in para]
    joined = " ".join(texts)
    if any(URL_RE.search(t) for t in texts):
        return "url", "carries a URL"
    if any(TABLE_RE.search(t) for t in texts):
        return "table", "aligned # ... # row"
    if any(BANNER_RE.match(t) for t in texts):
        return "banner", "decoration line"
    if BULLET_RE.match(texts[0]):
        return "bullet", "list shape, wrapped by hand"
    if any(t.startswith((" ", "\t")) for t in texts):
        # A continuation aligned deeper than `# text` is a shell snippet
        # when it starts with a command (`sudo mv ...`), prose otherwise.
        if any(t.split()[0].lower() in CMD_WORDS for t in texts):
            return "code", "shell snippet, aligned"
        return "shape", "aligned continuation"
    # A `# summary:` paragraph is refillable EXCEPT its first line: the
    # summary stays one line by rule, so only that line's own width is a
    # finding. The rest of the lead reflows like any prose.
    summary = SUMMARY_RE.match(texts[0]) is not None
    if not all(word_like(t) for t in (texts[1:] if summary else texts)):
        return "shape", "not the `# text` shape"
    if any(t.split()[0].lower() in CMD_WORDS for t in texts):
        return "code", "reads as a shell command line"
    # Code-shaped only if the code characters sit outside backtick spans.
    stripped = [BACKTICK_SPAN_RE.sub("C", t) for t in texts]
    if any(BAD_CHARS_RE.search(t) for t in stripped):
        return "code", "code characters outside backticks"
    if any(FLAG_TOKEN_RE.match(tok)
           for t in stripped for tok in t.split() if tok != "--"):
        return "code", "flag-like token"
    # A span opened on one line and closed on the next would swallow the
    # join's space into the quoted code: every line must balance its own.
    if any(t.count("`") % 2 for t in texts):
        return "broken-span", "backtick span crosses lines"
    region = " ".join(texts[1:]) if summary else joined
    longest = max((len(tok) for tok in _tokens(region)), default=0)
    if longest > limit - 2:
        # Verbatim config/type spans wider than any wrapped line: no
        # mechanical fix exists, so they sit like URL lines.
        return "overflow", f"token of {longest} cannot fit {limit - 2}"
    if summary and para[0][0] in over:
        return "summary", "summary line itself is over; tighten the text"
    return "prose", ""


def _tokens(joined):
    """Whitespace tokens of a joined paragraph, backtick spans atomic."""
    tokens = []
    for chunk in joined.split("`")[::2]:
        tokens.extend(chunk.split())
    for span in BACKTICK_SPAN_RE.findall(joined):
        tokens.append(span)
    return tokens


def rewrap(para, limit):
    """Re-flow a prose paragraph; returns the new contents per line."""
    joined = " ".join(content for _, content in para)
    max_content = limit - 2  # `# ` plus this reaches the moving limit
    out_lines, cur = [], ""
    for word in joined.split(" "):
        if cur and len(cur) + 1 + len(word) > max_content:
            out_lines.append(cur)
            cur = word
        else:
            cur = f"{cur} {word}" if cur else word
    if cur:
        out_lines.append(cur)
    return out_lines


def fix_text(text, limit):
    """Rewrite prose paragraphs over the limit; returns the fixed text.

    A `# summary:` paragraph keeps its first line verbatim and refills
    only the rest of the lead (classify reports the paragraph at all
    only when that first line itself fits).
    """
    lines = text.split("\n")
    comments = comment_indents(text)
    edits = []  # (first_lineno, n_lines, replacement_lines)
    for par_indent, para in paragraphs(lines, comments):
        over = [lineno for lineno, _ in para
                if len(lines[lineno]) > limit + par_indent]
        if not over:
            continue
        cls, _ = classify(par_indent, para, limit, over)
        if cls != "prose":
            continue
        prefix = f"{' ' * par_indent}# "
        if SUMMARY_RE.match(para[0][1]):
            replacement = [prefix + para[0][1]] + [prefix + c
                                                   for c in rewrap(para[1:],
                                                                   limit)]
        else:
            replacement = [prefix + c for c in rewrap(para, limit)]
        edits.append((para[0][0], len(para), replacement))
    for first, count, replacement in reversed(edits):
        lines[first:first + count] = replacement
    return "\n".join(lines)


EXEMPT = ("url", "table", "banner", "code", "overflow")


def over_limit(text, limit, include_exempt=False):
    """Every over-limit paragraph as (lineno, indent, class, detail, para).

    lineno is the first over-limit line of the paragraph (0-based).
    Exempt classes are skipped unless include_exempt (--all's listing).
    """
    lines = text.split("\n")
    found = []
    for par_indent, para in paragraphs(lines, comment_indents(text)):
        over = [lineno for lineno, _ in para
                if len(lines[lineno]) > limit + par_indent]
        if not over:
            continue
        cls, detail = classify(par_indent, para, limit, over)
        if cls in EXEMPT and not include_exempt:
            continue
        found.append((over[0], par_indent, cls, detail, para))
    return found


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Re-flow pure comment blocks to 80 columns plus indent")
    parser.add_argument("paths", nargs="*",
                        help="files or dirs (default: the module tree)")
    parser.add_argument("--fix", action="store_true", help="rewrite in place")
    parser.add_argument("--diff", action="store_true",
                        help="print the fix as a patch, write nothing")
    parser.add_argument("--limit", type=int, default=LIMIT)
    parser.add_argument("--all", action="store_true",
                        help="also list exempt lines")
    args = parser.parse_args(argv)

    root = Path(__file__).resolve().parent.parent  # flake/
    targets = [Path(p) for p in args.paths] or [root / "modules"]
    files = []
    for target in targets:
        if target.is_dir():
            files.extend(sorted(target.rglob("*.nix")))
        else:
            files.append(target)
    if not files:
        parser.error("no .nix files under the given path")

    remaining = []
    for path in files:
        text = path.read_text()
        if args.fix or args.diff:
            new_text = fix_text(text, args.limit)
            if new_text != text:
                if args.diff:
                    sys.stdout.writelines(difflib.unified_diff(
                        text.splitlines(True), new_text.splitlines(True),
                        fromfile=f"{path}", tofile=f"{path}"))
                else:
                    path.write_text(new_text)
                text = new_text
        lines = text.split("\n")
        for lineno, _, cls, detail, para in over_limit(text, args.limit):
            remaining.append(f"{path}:{lineno + 1}: [{cls}] {detail}: "
                             f"{dict(para)[lineno]}")
        if args.all:
            for lineno, _, cls, detail, _ in over_limit(
                    text, args.limit, include_exempt=True):
                if cls in EXEMPT:
                    print(f"{path}:{lineno + 1}: exempt [{cls}] {detail}")
    for line in remaining:
        print(line)
    return 1 if remaining else 0


if __name__ == "__main__":
    sys.exit(main())

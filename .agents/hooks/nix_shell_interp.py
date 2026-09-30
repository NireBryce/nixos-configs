#!/usr/bin/env python3
"""Find shell-shaped `${...}` inside Nix `''` strings -- AGENTS.md's trap
"`${...}` inside a Nix `''` string is interpolation": writing
`${terminfo[khome]}` meaning literal shell text is an evaluation error.

Called by edit-check-posttooluse.sh on every .nix the Edit/Write tools touch,
so the mistake shows up at write time, not at the next eval.

Why not just flag every `${` in a `''` string: most of them are deliberate
Nix interpolation (`${pkgs.foo}/bin/foo`), and no lexer can tell intent.
What it CAN tell is a `${` whose body cannot be a working Nix expression
and is a shell parameter expansion instead:

    ${#x} ${!x} ${@} ${*} ${1}          -- special/positional parameters
    ${x[...]} ${x:-y} ${x:=y} ${x:+y} ${x:?y}
    ${x%y} ${x#y} ${x/y} ${x^} ${x,}    -- subscripts and operators

Each of those is a Nix parse or eval error, so a hit is a real bug. A plain
`${HOME}` / `${VAR}` is NOT flagged: it parses as a Nix variable, and only
evaluation (scope) can say whether it exists -- the known gap.

A small lexer, not a regex, so escapes don't false-positive: `''${` (the
escape), `'''`, `''\\x`, and `$${` are literal text; `"..."` strings,
comments, and nested interpolations are tracked. Verified clean against
every .nix in the repo when written (2026-09-29).

Usage: nix_shell_interp.py FILE...   prints `FILE:LINE: message`, exit 0.
"""
import re
import sys

SHELLISH = re.compile(
    r"[#!@*]|[0-9]"
    r"|[A-Za-z_][A-Za-z0-9_]*(?:\[|:[-=+?]|%|#|/|\^|,)")

IDENT_CHAR = re.compile(r"[A-Za-z0-9_'-]")


def findings(text):
    """Yield (line, snippet) for each shell-shaped `${` in a `''` string."""
    i, n = 0, len(text)
    # Each frame: the state to return to when the interpolation's closing
    # brace arrives, plus that interpolation's brace depth.
    state = "code"
    stack = []  # list of [return_state, depth]
    while i < n:
        c = text[i]
        two = text[i:i + 2]
        if state == "code":
            if c == "#":
                j = text.find("\n", i)
                i = n if j < 0 else j
                continue
            if two == "/*":
                j = text.find("*/", i + 2)
                i = n if j < 0 else j + 2
                continue
            if c == '"':
                state, i = "dq", i + 1
                continue
            if two == "''" and not (i and IDENT_CHAR.match(text[i - 1])):
                state, i = "ind", i + 2
                continue
            if two == "${":
                if stack:
                    stack[-1][1] += 1
                i += 2
                continue
            if c == "{" and stack:
                stack[-1][1] += 1
            elif c == "}" and stack:
                if stack[-1][1] == 0:
                    state = stack.pop()[0]
                else:
                    stack[-1][1] -= 1
            i += 1
        elif state == "dq":
            if c == "\\":
                i += 2
            elif two == "$$":
                i += 2
            elif two == "${":
                stack.append(["dq", 0])
                state, i = "code", i + 2
            elif c == '"':
                state, i = "code", i + 1
            else:
                i += 1
        else:  # ind
            if text.startswith("'''", i) or text.startswith("''$", i):
                i += 3
            elif text.startswith("''\\", i):
                i += 4
            elif two == "''":
                state, i = "code", i + 2
            elif two == "$$":
                i += 2
            elif two == "${":
                if SHELLISH.match(text, i + 2):
                    line = text.count("\n", 0, i) + 1
                    eol = text.find("\n", i)
                    end = text.find("}", i, n if eol < 0 else eol)
                    yield line, text[i:end + 1] if end >= 0 else text[i:i + 20]
                    # Read on as the literal shell text it was meant to be:
                    # lexing `${#arr}` as Nix would open a comment at `#`
                    # and derail everything after this one real error.
                    i = end + 1 if end >= 0 else i + 2
                    continue
                stack.append(["ind", 0])
                state, i = "code", i + 2
            else:
                i += 1


def main(paths):
    for path in paths:
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError:
            continue
        for line, snippet in findings(text):
            print(f"{path}:{line}: {snippet} is shell syntax inside a Nix "
                  f"'' string, where ${{ starts Nix interpolation -- an "
                  f"eval error. Escape it as ''${{ (AGENTS.md, \"${{...}} "
                  f"inside a Nix '' string is interpolation\").")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

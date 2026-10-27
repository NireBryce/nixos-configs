---
name: comment-wrap
description: How to find and re-flow over-long comment blocks in the modules with the repo's checker and fixer.
when_to_use: A comment block runs past the column, a comment insert broke an existing wrap, asked to re-wrap or reflow comments, asked to run the comment-width sweep
---

# Re-flowing comment blocks

## Applies to

- A comment line or block visibly runs past the wrap the surrounding
  block uses, in any module.
- After inserting or extending comments in a module — the insert landed
  past the block's wrap, which is how the tree got its broken blocks
  (the 2026-10-26 summary-comment insert did it at scale).
- Asked for a repo-wide comment-width sweep or maintenance pass.
- Not for `#` inside a `''` or `"` string (shell text, emitted into the
  generated dotfile — the fixer never touches it, and neither should
  you) and not for trailing comments after code.

## The rule

A pure `#` comment line wraps at 80 columns plus the line's own indent —
a four-space-indented comment wraps at 84. The full statement, the
exempt shapes and why: wiki/config-structure/module-style-guide.md, "Comment width".

## Procedure

1. `just comment-wrap` — reports every over-limit block with a class
   tag, exits 1 on any. No output means done.
2. `just comment-wrap --diff` — preview the autofix and read it hunk by
   hunk. The fixer only rewraps unambiguous prose, but you are the
   reviewer.
3. `just comment-wrap --fix` — rewrite the prose blocks.
4. What the report still lists is hand work, by class:
   - `[summary]` — the `# summary:` line itself is over. It stays one
     line, so tighten the text: cut filler, keep every pointer, path,
     date and claim. The lead paragraph under it refills mechanically on
     the next `--fix`.
   - `[shape]`, `[broken-span]` — aligned continuations, `#!`-prefixed
     lines, a backtick span opened on one line and closed on the next.
     Rewrap by hand so every backtick span sits on one line and no line
     starts with a bare `--`.
   - `[bullet]` — hand-wrap with a hanging indent under the `- `.
5. Re-run `just comment-wrap` (exit 0 = done), then the usual checks:
   comment-only edits are evaluation-neutral, and the cheap guard is a
   `git diff` scan that every changed line starts with `#`.

## Why the exemptions are what they are

URLs must not break; `# ... # ...` tables, banners and commented-out
code are shaped, not prose, and refilling destroys the shape; a single
token wider than the column (a verbatim config span) has no wrap that
helps. None of these is ever "fixed" by the tool. If one is genuinely
too wide, tighten or restructure it by hand or leave it — do not make
the tool wrap it.

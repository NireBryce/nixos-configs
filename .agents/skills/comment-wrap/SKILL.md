---
name: comment-wrap
description: Finds over-long comment blocks in the modules and re-flows them with the repo's checker and fixer.
when_to_use: A comment block runs past the column, a comment insert broke an existing wrap, or asked to re-wrap, reflow or sweep comment widths.
---

# Re-flowing comment blocks

## Applies to

- A comment line or block runs past the wrap the surrounding block uses, in
  any module.
- After inserting or extending comments in a module: an insert that lands
  past the block's wrap breaks it (the 2026-10-26 summary-comment insert did
  this at scale).
- Asked for a repo-wide comment-width sweep or maintenance pass.
- Not for `#` inside a `''` or `"` string (shell text emitted into the
  generated dotfile; the fixer never touches it and neither should you), and
  not for trailing comments after code.

## The rule

A pure `#` comment line wraps at 80 columns plus the line's own indent: a
four-space-indented comment wraps at 84. The full statement, the exempt
shapes and the reasons are in wiki/config-structure/module-style-guide.md,
"Comment width".

## Procedure

1. `just comment-wrap` reports every over-limit block with a class tag and
   exits 1 if there are any. No output means done.
2. `just comment-wrap --diff` previews the autofix. Read it hunk by hunk; the
   fixer rewraps only unambiguous prose, and you review the result.
3. `just comment-wrap --fix` rewrites the prose blocks.
4. Fix by hand what the report still lists, by class:
   - `[summary]`: the `# summary:` line itself is over. It stays one line, so
     tighten the text: cut filler, keep every pointer, path, date and claim.
     The lead paragraph under it refills on the next `--fix`.
   - `[shape]`, `[broken-span]`: aligned continuations, `#!`-prefixed lines,
     or a backtick span opened on one line and closed on the next. Rewrap so
     every backtick span sits on one line and no line starts with a bare
     `--`.
   - `[bullet]`: wrap by hand with a hanging indent under the `- `.
5. Re-run `just comment-wrap` (exit 0 = done). Then check that the change is
   comment-only: comment-only edits do not change evaluation, and a `git
   diff` scan confirms every changed line starts with `#`.

## Why the exemptions are what they are

- URLs must not break.
- `# ... # ...` tables, banners and commented-out code have a shape, and
  refilling destroys it.
- A single token wider than the column (a verbatim config span) has no wrap
  that helps.

The tool never wraps these. If one is too wide, tighten or restructure it by
hand, or leave it.

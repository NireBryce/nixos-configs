# 5. Writing a trap down does not stop you walking into it

_Last modified: 2026-09-29_

## Index entry

§5 in [agent-lessons-learned.md](../agent-lessons-learned.md)

## The lesson

`CLAUDE.md` gained a section on reading generated dotfiles. Within minutes I hit
both halves: queried `home.file.".zshrc"` (the attribute is `"./.zshrc"`, and a
wrong name returns **empty rather than erroring**), then found `.bashrc` empty
and briefly believed I had caused a regression — it has no `.text` at all, being
built from `.source`.

Both are now in `CLAUDE.md` *and* in `just dotfiles`, because the fix is a tool
that makes the mistake impossible, not a warning.

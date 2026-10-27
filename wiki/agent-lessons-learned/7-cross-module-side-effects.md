# 7. Cross-module side effects are invisible without a fingerprint

_Last modified: 2026-09-29_

## Index entry

§7 in [agent-lessons-learned.md](../agent-lessons-learned.md), which keeps a one-line version of every lesson, filed by when it applies. This page is the full account.

## The lesson

Removing fish — an unused shell — removed the man page index, because
`fish.nix:683` sets `programs.man.generateCaches = lib.mkDefault true` inside
`mkIf cfg.generateCompletions`. Nothing here mentions `programs.man`. `apropos`
would have stopped working with no visible cause.

`just diff` reported `homeFileHashes: removed '.manpath'` and that was the whole
thread. **Run it across any change that removes a module**, however unrelated.

The same tool caught a comment-only edit shipping fourteen lines into `~/.zshrc`:
`#` inside a `''` string is shell text, not a Nix comment.

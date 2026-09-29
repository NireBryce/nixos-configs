# 7. Cross-module side effects are invisible without a fingerprint

_Last modified: 2026-09-29_

§7 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §7's full account.

Removing fish — an unused shell — removed the man page index, because
`fish.nix:683` sets `programs.man.generateCaches = lib.mkDefault true` inside
`mkIf cfg.generateCompletions`. Nothing here mentions `programs.man`. `apropos`
would have stopped working with no visible cause.

`just diff` reported `homeFileHashes: removed '.manpath'` and that was the whole
thread. **Run it across any change that removes a module**, however unrelated.

The same tool caught a comment-only edit shipping fourteen lines into `~/.zshrc`:
`#` inside a `''` string is shell text, not a Nix comment.

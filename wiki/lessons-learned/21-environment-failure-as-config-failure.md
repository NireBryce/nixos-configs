# 21. An environment failure can wear a config failure's clothes

_Last modified: 2026-09-29_

§21 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §21's full account.

That same failure presented as a flake-parts evaluation trace — `while
evaluating the attribute 'root.result'` — which reads as a broken flake. Eight
lines lower: `HTTP error 401 … "Bad credentials"`. An expired GitHub token in
`~/.config/nix/nix.conf`, outside the repo, unrelated to any of the work.

**Read to the bottom of a nix trace before believing the top of it.** Nix puts
the innermost failure last; the frames above are the path taken, not the cause.

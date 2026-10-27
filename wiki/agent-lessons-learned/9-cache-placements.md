# 9. Caches in nix have three placements, and the default is the expensive one

_Last modified: 2026-09-29_

## Index entry

§9 in [agent-lessons-learned.md](../agent-lessons-learned.md), which keeps a one-line version of every lesson, filed by when it applies. This page is the full account.

## The lesson

| placement | cost | staleness |
|---|---|---|
| build time (`runCommand` over a `buildEnv`) | rebuilds when *any* input changes | never stale |
| activation (`home.activation`) | every switch, incrementally | current after each switch |
| timer (systemd user unit) | nothing at build or switch | bounded by the interval |

Both built-in man options take the first. `mandb` without `--create` *updates*
rather than rebuilds, which is what makes the other two viable.

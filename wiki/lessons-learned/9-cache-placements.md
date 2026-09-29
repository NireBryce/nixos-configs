# 9. Caches in nix have three placements, and the default is the expensive one

_Last modified: 2026-09-29_

§9 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §9's full account.

| placement | cost | staleness |
|---|---|---|
| build time (`runCommand` over a `buildEnv`) | rebuilds when *any* input changes | never stale |
| activation (`home.activation`) | every switch, incrementally | current after each switch |
| timer (systemd user unit) | nothing at build or switch | bounded by the interval |

Both built-in man options take the first. `mandb` without `--create` *updates*
rather than rebuilds, which is what makes the other two viable.

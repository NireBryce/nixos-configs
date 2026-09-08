## what shipped

`just lint` — statix + deadnix + a 5000-line file-size cap, over every
git-tracked file, run from `flake/scripts/lint.py`.

Not a plain pass/fail: this repo had never run either linter before, so a
first run turned up 170 statix findings and 3 deadnix ones, all pre-existing.
Requiring a clean tree before this could land would mean fixing all 173
first, which is disproportionate (homelab, not production). Instead it's a
ratchet against a committed baseline, `flake/scripts/lint-baseline.json`,
seeded at today's real counts:

```json
{ "statix": 170, "deadnix": 3, "oversized_files": 0 }
```

A commit that adds a new finding fails the check. A commit that fixes one
auto-lowers the baseline file in place and passes — the number can only go
down from here, never back up quietly.

## where it runs

- `just lint` by hand, or `just preflight` (new, bundles `check` + `modules`
  + `lint`).
- CI, added as a step in `.github/workflows/check.yml` — installs
  statix/deadnix via `nix shell` since they're normally only on PATH through
  the home-manager profile on a real host.
- `.githooks/pre-commit`, opt-in via `just install-hooks`
  (`git config core.hooksPath .githooks`). Re-stages the baseline file
  itself if it improved, so the lowered number rides along in the commit
  that earned it instead of showing up as unrelated dirty state after.

## why statix/deadnix specifically

Both were already installed as home-manager packages
(`nirePackages/nix-utils/{statix,deadnix}/`) — for a human to run by hand,
which nothing was actually doing. This wires up tools already present in the
tree rather than adding a new dependency.

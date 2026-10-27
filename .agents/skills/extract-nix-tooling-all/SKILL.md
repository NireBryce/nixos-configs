---
name: extract-nix-tooling-all
description: Sweeps the repo for Nix patterns, flake machinery, scripts and traps that would work in any flake, and updates the extraction candidates folder.
when_to_use: Asked what Nix patterns here are reusable, or to refresh the Nix extraction candidates.
---

# Sweeping for general Nix candidates

## Applies to

Asked "what Nix patterns here are reusable", or to refresh
`_loose-ends/extraction-candidates/nix/` — a deliberate, standalone pass.
Not: a candidate noticed mid-task (`extract-nix-tooling`); the non-Nix
sweep (`extract-agent-tooling-all`); creating or pushing to the general
repo (only when the user asks in those words).

## Relationship to the other three

Procedure is `extract-agent-tooling-all`'s steps (worktree, scope,
reconcile existing candidates first, survey, rank, report, ship); test is
`extract-nix-tooling`'s. Read both. Only the surfaces differ.

## Where to look

Use `ls`, not this list, for what currently exists in each; the table says
where to look, not what you'll find.

| Surface | Typical candidate shape |
|---|---|
| `flake/flake.nix` | The manifest, and the already-extracted inputs (`dirs-as-categories`, `flake-module-graph`) a candidate may extend instead of standing alone |
| `flake/modules/general-config/` | Cross-cutting modules whose mechanism isn't this fleet's (`drop-unsupported-packages.nix`), not host config |
| `flake/scripts/` | `modules.py` (name/class/untracked checks), `lint.py` (ratchet), `diff-config.sh`, `diff-deployed.sh`, `rebuild.sh`, `pkg-availability.py`, `history-line.sh` |
| `flake/doc/` | Rationale docs and trailheads (`trailhead-home-manager-standalone.md`) — often the general explanation behind a pattern |
| `wiki/module-style-guide.md` | Formatting rules, and the module-bottom history-section convention (`trim-history`) |
| Nix-shaped skills | `new-flake-module`, `home-manager-dotfiles`, `package-platform-support`, `impermanence-initrd`, `review`'s Nix checks |
| `wiki/lessons-learned.md` | §s about evaluation vs build vs runtime, freeform options, interpolation |
| AGENTS.md "Traps" | Nix traps stated inline (`${…}` in `''` strings, freeform settings) |

Host-specific trees (`flake/modules/host-config/`, `flake/modules/homelab-config/`)
rarely yield a whole candidate; skim them for the *trap* behind a fix, not
the fix itself.

## Calibrate

Same as the agent sweep: mechanisms, not topics. "How we do Home Manager"
is a topic; "HM `home.file.<n>.text` concatenates across modules, so two
modules writing one file double it silently — and here's how to read the
generated file back" is a mechanism with evidence.

## See also

- `extract-agent-tooling-all` — the procedure.
- `extract-nix-tooling` — the test.

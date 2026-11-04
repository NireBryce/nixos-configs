---
name: extract-nix-tooling-all
description: Sweeps the repo for Nix patterns, scripts and traps that would work in any flake, and updates the extraction candidates folder.
when_to_use: Asked what Nix patterns here are reusable, or to refresh the Nix extraction candidates.
---

# Sweeping for general Nix candidates

## Applies to

Use when asked "what Nix patterns here are reusable", or to refresh
`_loose-ends/extraction-candidates/nix/`. This is a standalone pass. It does
not cover:

- a candidate noticed mid-task (`extract-nix-tooling`);
- the non-Nix sweep (`extract-agent-tooling-all`);
- creating or pushing to the general repo, which happens only when the user
  asks.

## Relationship to the other three

The procedure is `extract-agent-tooling-all`'s steps (worktree, scope,
reconcile existing candidates first, survey, rank, report, ship), and the
generality test is `extract-nix-tooling`'s. Read both. Only the surfaces to
survey differ.

## Where to look

Use `ls` to see what currently exists in each surface; the table says where to
look, not what you will find.

| Surface | Typical candidate shape |
|---|---|
| `flake/flake.nix` | The manifest, and the already-extracted inputs (`dirs-as-categories`, `flake-module-graph`) a candidate may extend instead of standing alone |
| `flake/modules/general-config/` | Cross-cutting modules whose mechanism isn't this fleet's (`drop-unsupported-packages.nix`), not host config |
| `flake/scripts/` | `modules.py` (name/class/untracked checks), `lint.py` (ratchet), `diff-config.sh`, `diff-deployed.sh`, `rebuild.sh`, `pkg-availability.py`, `history-line.sh` |
| `flake/doc/` | Rationale docs and trailheads (`trailhead-home-manager-standalone.md`) — often the general explanation behind a pattern |
| `wiki/config-structure/module-style-guide.md` | Formatting rules, and the module-bottom history-section convention (`trim-history`) |
| Nix-shaped skills | `new-flake-module`, `home-manager-dotfiles`, `package-platform-support`, `impermanence-initrd`, `review`'s Nix checks |
| `wiki/agent-lessons-learned.md` | §s about evaluation vs build vs runtime, freeform options, interpolation |
| AGENTS.md "Traps" | Nix traps stated inline (`${…}` in `''` strings, freeform settings) |

Host-specific trees (`flake/modules/host-config/`,
`flake/modules/homelab-config/`) rarely yield a whole candidate. Skim them for
the trap behind a fix, not the fix itself.

## Calibrate

Look for mechanisms, not topics, as in the agent sweep. "How we do Home
Manager" is a topic. "HM `home.file.<n>.text` concatenates across modules, so
two modules writing one file double it silently; here is how to read the
generated file back" is a mechanism with evidence.

## See also

- `extract-agent-tooling-all` — the procedure.
- `extract-nix-tooling` — the test.

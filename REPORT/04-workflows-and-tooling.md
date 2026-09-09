# 04 — Workflows, tooling, and verification practice

_As of: 2026-09-08. Sources: `.justfile`, `flake/scripts/` (16 files),
`wiki/scripts/`, `.claude/`, `.vscode/`, `dev-shells/`._

## `just` is an interface, not logic

`.justfile` states its own contract in the header: recipes are one line of
dispatch plus the one-line summary `just --list` reads; anything with a
conditional, pipeline, or a reason worth explaining belongs in
`flake/scripts/` next to the code it explains. Every recipe points at
`flake/` explicitly because the repo root has no `flake.nix`.

The `host` variable derives from `hostname` by checking for a matching
`nireHost/<name>-configuration.nix` on disk (so a new host is picked up
with no edit here), falling back to `nire-durandal` off-host. Override
**before** the recipe name: `just host=nire-durandal build`. This exists
because a flat fallback once built the wrong machine for an hour, silently.

Recipe groups:

| Group | Recipes | Notes |
|---|---|---|
| Static checks | `check` (flake check, no build), `modules` (name collisions/orphans/untracked), `lint` (ratchet), `wiki-lint` (11 subchecks), `preflight` = check+modules+lint | `wiki-lint` is deliberately **not** in `preflight` yet — see R5 in [06](06-recommendations.md) |
| Report-only doc tools | `wiki-churn`, `wiki-stale-refs` | never fail; heuristics with documented false-positive classes |
| Build & apply | `build`, `boot`, `switch` (via `rebuild.sh` → `nh os`/`nh darwin`) | host-only: no remote builder, no binfmt; `boot` preferred for initrd/bootloader/impermanence work |
| Verify before/after | `baseline`, `diff-deployed`, `root-drift`, `hm-collisions`, `fingerprint`, `fingerprint-home`, `diff <ref>`, `dotfiles`/`dotfile` | the repo's "what is it *actually* running" toolkit |
| Fleet ops | `reach` (mDNS→Tailscale→DNS ssh), `opencode-attach` (cube's agent server), `tailscale-acl` (policy via API), `age-key` (sops recipient derivation), `update`, `available` (platform/Homebrew overlap), `threads` (issue/wiki search) | |

## The verification discipline (the repo's core practice)

The ordering principle, learned the hard way (`wiki/lessons-learned.md`,
§§15/18/24/25/37): **evaluation ≠ build ≠ run**, and each rung has failed
here in a way the cheaper rung could not see. Hence:

1. `just preflight` — static checks, cheap, every change.
2. Forced toplevel eval per touched host:
   `nix eval --raw '.#nixosConfigurations.<host>.config.system.build.toplevel.drvPath'`
   — "evaluating a cheap attribute proves nothing".
3. `just diff <ref>` — when the drvPath moves, see *what* moved
   (`diff-config.sh` evaluates both sides in a throwaway worktree; a
   permuted `systemPackages` list moves the hash without changing values).
4. `just build`/`boot`/`switch` **on the host itself** — no remote builder,
   no binfmt; `rebuild.sh` says so rather than failing inside nix.
5. Before switching on a machine: `just baseline` (capture what is running;
   unrecoverable after the next generation boots), `just root-drift`
   (what impermanence will eat), `just hm-collisions` (files HM will take
   over).

"Fingerprint by all means, but not only by fingerprint" is written into
both `AGENTS.md` and the `fingerprint` recipe's own comment.

## The lint ratchet

`flake/scripts/lint.py check` runs statix + deadnix + an oversized-file
check and compares counts against committed `flake/scripts/lint-baseline.json`
(currently: statix 3, deadnix 0, oversized 0). Counts may fall, never rise.
Rationale (script header): a plain pass/fail linter on a legacy tree either
blocks everything or gets `--no-verify`'d into worthlessness; a ratchet
starts from today's truth. Enforced three ways: locally via
`.githooks/pre-commit` (opt-in, `just install-hooks`; silently skips if the
tools are off PATH, and re-stages the baseline on improvement — with a
documented linked-worktree GIT_DIR trap), and in CI as the lint step.

## wiki-lint

`wiki/scripts/check_wiki.py check` — 11 subchecks: per-category "Imported
by" lists vs parsed host imports; the `categories/README.md` index table;
`hosts.md`'s host table vs `hosts.nix` + actual impermanence importers;
every `` `just …` `` mention vs recipe names; every "skill `name`" mention
vs `.claude/skills/`; the `.sops.yaml` enrollment claim vs actual
recipients; routed tailnet URLs vs `caddy.nix`'s Caddyfile; relative links;
heading anchors (GitHub slugs); `## Contents` blocks; `_Last modified`
dates (well-formed, not future). Plus `gen-contents` as the fixer. This is
the mechanism that makes the "wiki is a link layer" rule survivable.

## Secrets operations

- sops-nix; `secrets.yaml` committed-encrypted; `.sops.yaml` enrolls the
  four hosts by age key.
- `just age-key` derives a host's recipient from its SSH host key
  (`host-age-key.sh`, via ssh-to-age) and prints the enrollment steps; it
  only ever reads public material.
- `wiki/maintenance-schedule.md` is the plaintext credential-expiry ledger
  (10 items: Tailscale keys/tokens, age recipients, restic, QNAP host pin,
  forgejo/Grafana creds, Syncthing certs, and the GitHub
  `FLAKE_LOCK_TOKEN`), tended by skill `maintenance-schedule`.
- Three harness hooks (`.claude/hooks/`, wired in `.claude/settings.json`):
  pre-tool-use guards on `sops -d` without `--extract` and on reading
  `/run/secrets/`, a git-destructive-command guard ("ask, never deny"),
  and a post-tool-use scanner for secret-shaped values in output (born
  from a 2026-08-26 transcript leak incident, documented in the script).

## The agent harness

- **20 skills** in `.claude/skills/` — plain markdown, readable as files by
  any agent. Patterns worth copying: every skill exists because a real
  incident happened; recurring traps become skills, checkable traps become
  hooks or lint. Key operational ones: `ship` (landing flow),
  `investigate-bug` (check known threads first — backed by `just threads`),
  `propose-issue` (files only in this repo), `use-a-worktree`,
  `wiki-sync`/`trim-docs`/`fact-hygiene` (docs discipline),
  `new-flake-module`/`new-host-config`/`new-homelab-service` (task
  runbooks).
- `.claude/completed_todos/` archives finished working todo lists — the
  paper trail of a 2026-08-25 "turn habits into checks" pass that produced
  the lint ratchet and several skills.
- `settings.local.json` is gitignored; everything else in `.claude/` is
  committed, i.e. the harness is treated as part of the repo, versioned
  and reviewed like code.

## Editor and dev shells

- `.vscode/settings.json`: nixd with formatting disabled twice (belt and
  braces, both commented), option docs via `builtins.getFlake` pointing at
  the checkout, ruler at 76/80/120, `tabWidth 4`.
- `dev-shells/{python,rust}/`: scaffolding templates (a `create` recipe
  copies the flake into a new project dir), so ad-hoc projects get nix
  toolchains without touching this flake.
- `_lab-notebook-nixos/`: Elly's Obsidian vault, tracked except
  `.trash/` and `workspace.json` (but see R6: workspace.json is still
  tracked).

## Recommendations

- **R5 — wire `wiki-lint` into CI.** `check.yml` mirrors
  `check`+`modules`+`lint` but not `wiki-lint`, so the entire doc-rot
  safety net is opt-in local. The recipe's own comment says "not yet in
  `preflight`" — CI is the easier, more valuable half of that fix (fresh
  clones don't have hooks installed). The checker is platform-independent
  Python, so it adds no flake eval cost. After it has run green for a
  while, add it to `preflight` too.
- **R6 — `git rm --cached _lab-notebook-nixos/.obsidian/workspace.json`.**
  The `.gitignore` rule (added later) cannot untrack an already-tracked
  file, so Elly's live Obsidian workspace state still lands in every
  commit's status view and will churn forever. (Verified via
  `git ls-files`, 2026-09-08.)
- **R7 — prune stale branches.** Local: `exp-module-cleanup`,
  `flake-parts-consolidation` (both superseded — the port landed).
  Remote: ~25 branches including a stale `update_flake_lock_action`. If
  the ship flow's delete-on-merge is followed, only these older ones
  remain; a one-time `git branch -d` / `git push origin --delete` sweep
  (after a `--merged origin/experimental` check) would make branch listing
  meaningful again.

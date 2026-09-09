# 06 — Consolidated recommendations

_As of: 2026-09-08. Every item cites its evidence; IDs match the inline
recommendation sections in [01](01-overview.md)–[05](05-github-usage.md).
Nothing here is structural — the architecture, the checking culture, and
the GitHub automation are sound; the findings are staleness and coverage
gaps, which is the honest failure mode of a repo this heavily documented._

## Summary

| ID | Priority | Finding | Action |
|---|---|---|---|
| R1 | High | `README.md` host list omits `nire-lysithea`; "flake.nix" wording hides the `flake/` subdirectory | Point at `wiki/hosts.md` instead of restating |
| R2 | High | `AGENTS.md` claims "all five hosts"; there are four | Fix the count; consider a wiki-lint subcheck |
| R3 | Medium | `wiki/module-style-guide.md` counts ("151 of 151", 70, 106) are stale vs 263 files | Refresh on a cadence or make recomputable |
| R4 | Low | No `.editorconfig` | Add one (not a formatter) |
| R5 | High | `wiki-lint` runs nowhere automatic — not in CI, not in `preflight` | Add a CI step; later `preflight` |
| R6 | Medium | `.obsidian/workspace.json` tracked despite gitignore | `git rm --cached` |
| R7 | Low | ~25 stale remote branches, 2 stale local branches | One-time merged-check sweep + R9 going forward |
| R8 | Medium | `nix-installer-action@main` unpinned in `check.yml` | Pin by SHA, matching `update-flake-lock.yml` |
| R9 | Low | Hand-merged PRs leave head branches behind | Enable auto-delete of head branches |
| R10 | — | Zero-approval ruleset is correct for a solo repo | None; revisit if a second maintainer appears |
| R11 | Low | `check.yml:77-81` comment says `experimental` "has no ruleset of its own" — stale since the 2026-09-03 default-branch flip | Update the comment |
| R12 | Low | CI sops warmup skips `nire-lysithea` (darwin), which `.sops.yaml` enrolls | Verify and extend the warmup loop, or note why not |

## What is already strong (worth keeping as-is)

- **Checks instead of memories**: the lint ratchet (counts fall, never
  rise), `just modules` (collision/orphan/untracked), and wiki-lint's
  eleven subchecks make the repo's prose self-verifying to an unusual
  degree. Most repos of any size lack this.
- **The `#`-comment discipline**: mechanism + evidence + date in long
  comments (`check.yml`'s two-wrong-theories post-mortem,
  `flake/flake.nix`'s formatter note) — written so the next person does
  not re-chase ruled-out theories.
- **Secrets handling**: committed-ciphertext sops with a derivation script
  for new hosts, a plaintext *expiry* ledger (the right thing to keep in
  plaintext), transcript-guard hooks born from a real leak, and a CI PAT
  with documented rationale, preflight, and SHA pinning.
- **The trunk + promotion model** fits a homelab: `main` means "booted on
  hardware", the promotion PR records the verification, and the rulesets
  enforce what the conventions would only request.
- **Templates encode process**: the bug-report form's "How far did it
  get?" rungs and `just threads` field, the PR template's "Deliberately
  left alone" section.

## The items, with evidence

### R1 (High) — `README.md` is stale about hosts and layout
`README.md` lists durandal, tenacity, cube and omits `nire-lysithea`
(aarch64-darwin), which `nireHost/hosts.nix` defines and `.sops.yaml`
enrolls. Its Layout section also says "`flake.nix` imports every `.nix`
file under `flake/modules/`" without saying the flake lives in `flake/` —
the repo root has no `flake.nix`, a fact `.justfile` has to explain in its
own header. Suggested fix (matches the repo's link-layer philosophy):
replace the inline host list with a pointer to `wiki/hosts.md` (one line,
cannot rot) and say "the flake entry point is `flake/flake.nix`; the root
has none" in Layout.

### R2 (High) — `AGENTS.md`'s host count is wrong
`AGENTS.md` (Platform support section): "`ellyHomeManager` is shared
verbatim by all five hosts including `nire-lysithea`". Four hosts exist
(`hosts.nix`: three `nixosConfigurations` + one `darwinConfigurations`;
the issue-template dropdown and `.sops.yaml` agree). This matters more
than the number: AGENTS.md is the file agents are told to trust, and its
own doc-culture says stale claims get mechanically checked. Suggested fix:
correct to "four"; optionally extend `wiki/scripts/check_wiki.py` (which
already checks AGENTS.md's sops-enrollment claim) with a hosts-in-prose
subcheck so the class is covered, not just this instance.

### R3 (Medium) — module-style-guide counts have gone false
`wiki/module-style-guide.md` (dated 2026-08-08 counts): "The module header
— 151 of 151 files", "`# # description` — 70 files", "`with pkgs` — 106
files". The tree is now 263 `.nix` files. The page's stated reason for
using counts is "checkable rather than asserted" — they are now checkably
wrong, which trains readers to ignore them. Suggested fix: either refresh
on a cadence (a line in `wiki/maintenance-schedule.md`) or replace each
count with the one-liner that recomputes it (`grep -rc … | wc -l` style),
which can then be wiki-lint-checked.

### R4 (Low) — add a `.editorconfig`
See [03](03-conventions-and-style.md). Purely additive; does not import a
formatter.

### R5 (High) — wiki-lint is not automatic
`just wiki-lint` is the mechanism that makes the "wiki is a link layer"
rule survivable, yet it is excluded from `preflight` (the recipe's own
comment says "not yet in `preflight`") and from CI — `check.yml` mirrors
only `check`+`modules`+`lint`. A refactor that breaks wiki claims passes
CI green and lands. The checker is stdlib Python against the working
tree; a CI step is two lines and no flake eval cost. Suggested sequence:
add to `check.yml` first (fresh clones have no hooks anyway), then add to
`preflight` once it has been green for a while.

### R6 (Medium) — tracked file that gitignore was written to exclude
`git ls-files` shows `_lab-notebook-nixos/.obsidian/workspace.json`
tracked; `.gitignore` added it later, which cannot untrack an existing
file. Consequence: Elly's live Obsidian UI state (open panes, cursor) sits
in the index and shows up as noise on every status/diff. Action:
`git rm --cached _lab-notebook-nixos/.obsidian/workspace.json`.

### R7 (Low) — branch debris
Local: `exp-module-cleanup`, `flake-parts-consolidation` (superseded by
landed work — the port is in `wiki/flake-parts-port-notes.md` and merged).
Remote: ~25 branches, mostly merged feature/installer branches plus one
`update_flake_lock_action` from the workflow's failed first run. Action:
one-time sweep with `git branch --merged origin/experimental` /
`git branch -r --merged origin/experimental` before deleting; R9 prevents
recurrence for hand-merges.

### R8 (Medium) — pin the CI's nix installer
`check.yml:92` uses `DeterminateSystems/nix-installer-action@main`;
`update-flake-lock.yml` pins both its actions by full commit SHA (PR #204,
with the reasoning in the workflow header: branch refs are mutable).
`check.yml` runs without write permissions so the blast radius is smaller,
but the failure mode — upstream breaks `main`, every PR goes red, nobody
remembers why — is identical. Pin it; `dependabot`/manual bumps from there.

### R9 (Low) — auto-delete head branches
See [05](05-github-usage.md). Complements the ship flow (which still does
the local delete + checkout explicitly); catches web-UI and PAT-workflow
merges that bypass it.

### R11 (Low) — stale ruleset comment in `check.yml`
`check.yml:77-81`: "`experimental` added 2026-08-25 … even though
`experimental` has no ruleset of its own to make that a requirement."
Since 2026-09-03 the default-branch ruleset (which targets
`~DEFAULT_BRANCH`) covers `experimental` and makes the CI check required —
per `.claude/skills/ship/SKILL.md`'s ruleset section. The comment
predates the flip; updating it is a two-line docs fix in the same file.
(Worth noting the repo's usual rule — "a change that makes a comment stale
corrects it in the same change" — didn't fire here because the ruleset
change touched no code CI would re-read.)

### R12 (Low) — CI sops warmup skips the darwin host
`check.yml:94-99` warms the `secrets.yaml` store registration for
`nire-durandal`, `nire-tenacity`, `nire-cube` only. `.sops.yaml` also
enrolls `nire-lysithea`, and `nire/system/secrets/sops-darwin.nix` exists,
so the darwin config plausibly evaluates the same literal file inside
`nix flake check --all-systems` — the exact race the warmup exists for —
leaving only the inline retry as mitigation on that path. Action: confirm
the darwin config pulls the same `secrets.yaml`; if so, add a
`darwinConfigurations.nire-lysithea` eval to the warmup loop. If the
darwin path doesn't touch that file, record why in the loop comment so
the question stays answered.

### Unnumbered minor notes

- `.gitignore:3` ignores `.history/nire-galatea`; no machine or host of
  that name exists in this tree (it appears only in an ssh authorized key
  and a historical comment in `sops.nix`). Harmless; safe to drop with the
  next `.gitignore` touch.
- `_lab-notebook-nixos/` has no README stating what it is or that agents
  should leave it alone — its `human-written-docs/agent ignore - scratchpad
  ideas.md` filename carries that signal informally. A three-line README
  would make it explicit.
- **This `REPORT/` directory is currently untracked.** If it should stay,
  commit it (ship flow); if it was a one-time audit, it can be deleted or
  parked — but note nothing lints it, so any wiki/ file it links to that
  later moves will strand these links silently.

## If only three things get done

1. **R2** — fix "five hosts" in AGENTS.md (a one-word edit to the repo's
   most-trusted file).
2. **R5** — wiki-lint in CI (two lines; closes the only automated-check
   gap in the docs system).
3. **R1** — README host list → pointer to `wiki/hosts.md`.

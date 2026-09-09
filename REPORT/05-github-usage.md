# 05 — How this repo uses GitHub

_As of: 2026-09-08. Sources: `.github/` (all files read), `.claude/skills/ship/SKILL.md`,
`wiki/open-threads.md`, `wiki/maintenance-schedule.md`, git/PR history._

Repo: **`NireBryce/nixos-configs`**, remote `origin`, solo maintainer.
GitHub is used as: trunk-based PR queue with a promotion gate, a
scheduled-dependency robot, and the bug tracker — with an unusual amount of
institutional memory encoded in templates and skill files because agents do
most of the operating.

## Branch model: trunk + promotion

- **`experimental` is the default branch and the trunk.** All work lands
  here, always via PR (the ruleset enforces it; agents enforce it again via
  skill `ship`).
- **`main` is the promoted known-good.** It moves only via a PR from
  `experimental`, and only for configs verified on hardware. The promotion
  PR (`gh pr create --base main --head experimental`, title
  `promote: …`) is the record of *why* `main` moved — what booted, what
  switched.
- As of 2026-09-08: `main` is 0 commits ahead, `experimental` 157 ahead
  (`git rev-list --left-right --count main...experimental`) — main was
  last promoted 2026-09-08 itself (PR #201), so the gap is one day of
  trunk work. Promotion is frequent relative to most solo repos; that is
  deliberate (main tracks "booted on hardware", not "stable").

### Rulesets (enforced by GitHub, described in the ship skill)

- The ruleset originally written for `main` (2026-08-21) targets
  `~DEFAULT_BRANCH`, so it followed the default-branch flip to
  `experimental` automatically: no deletion, no force-push, PR required,
  **zero approvals** (solo repo — the conversational confirm is the review),
  CI check required.
- `main` is protected by name with the same rules.
- A single GitHub-level rule carries no "why"; the why lives in the ship
  skill's ruleset section and in `wiki/history.md`.

## The `ship` flow (how work lands)

Codified in `.claude/skills/ship/SKILL.md`; highlights that define the
repo's GitHub etiquette:

1. `git fetch origin` first — sessions run concurrently on several hosts
   and branches go stale fast.
2. `just preflight` + a forced toplevel eval per touched host before even
   opening the PR — CI is "a minutes-later backstop".
3. Branch (`feat/`/`fix/`/`docs/` prefix), explicit-pathspec commits,
   messages written to a file (`-F`), provenance trailer
   (`Co-Authored-By: <agent>`).
4. `gh pr create --base experimental`; body follows the PR template
   headings.
5. **One combined confirmation**: "merge, and delete the branch afterward?"
   — asked up front, both actions in the same turn. Never
   `gh pr merge --delete-branch` (remote-only; the flow also wants the
   local branch gone and `experimental` checked out and pulled).
6. Merge method: **`--rebase` for single-commit PRs** (a merge bubble for
   nothing), **`--merge` for multi-commit PRs** (this repo puts real
   reasoning in individual commit messages; squashing flattens it).
7. **Closing keywords are not trusted**: GitHub's "Fixes #N" auto-close
   silently failed on three correct PRs into the default branch (issue
   #177, 2026-09-06) — after merging, `gh issue view <N> --json state` and
   close explicitly if still `OPEN`.
8. Stacked PRs are retargeted explicitly *before* the base merges.

## CI: `.github/workflows/check.yml` (name: `flake-check`)

- Triggers: all `pull_request`s, plus pushes to `main` and `experimental`.
  One job, `ubuntu-latest`, 15-minute timeout, no secrets; actions
  `checkout@v4` and `DeterminateSystems/nix-installer-action@main`.
- Steps mirror `just check`/`modules`/`lint` exactly:
  1. Warmup: `nix eval` of each sops-enrolled host's toplevel drvPath —
     mitigation for an intermittent `secrets.yaml` store-registration race
     under `nix flake check --all-systems --no-build`.
  2. `nix flake check --all-systems --no-build`, with an inline single
     retry (5s) that emits a `::warning::` referencing the documented race.
  3. `python3 scripts/modules.py check modules` — catches the
     module-collision/orphan class a `--no-build` check would skip.
  4. Lint ratchet: `nix shell nixpkgs#statix nixpkgs#deadnix --command
     python3 scripts/lint.py check` — the backstop for the opt-in local
     pre-commit hook.
- **Eval-only is deliberate** (long header comment): building full
  NixOS/darwin toplevels per PR is disproportionate for a homelab, and
  eval errors are the bug class CI *can* catch. The known gap — a lock
  bump that evaluates but breaks a build — is tracked as issue #205
  (proposed fix: build on `nire-cube`).

## The dependency robot: `update-flake-lock.yml`

- Weekly, `cron: '0 9 * * 1'` (Mondays 09:00 UTC) + manual dispatch;
  checks out `experimental` explicitly; uses
  `DeterminateSystems/update-flake-lock` with `path-to-flake-dir: flake`,
  opening a `chore: update flake.lock` PR whose body frames the lock diff
  as the review.
- **The PAT story is the interesting part.** The workflow uses a
  fine-grained PAT secret (`FLAKE_LOCK_TOKEN`, Contents+PR read/write on
  this repo), not `GITHUB_TOKEN`, for two documented reasons: a
  `GITHUB_TOKEN`-opened PR does not trigger this repo's own
  `pull_request` CI, and the repo-wide "allow GitHub Actions to create and
  approve pull requests" switch is off. The first scheduled run
  (2026-09-07) failed exactly there; PR #204 switched to the PAT and added:
- **Token preflight** (fails fast with a `::error::` if the secret is
  missing/rejected; reads the `github-authentication-token-expiration`
  header; emits a warning when ≤30 days of life remain), and **action
  pinning by full commit SHA** for both DeterminateSystems actions,
  because they run with `contents: write`.
- On failure or approaching expiry, a plain-`GITHUB_TOKEN` step creates or
  comments on a single reusable issue ("update-flake-lock: weekly lock PR
  needs attention"), searched up by title so it never multiplies.
- `FLAKE_LOCK_TOKEN` is item 10 in `wiki/maintenance-schedule.md` —
  deliberately a repo secret rather than a sops secret (CI needs it; sops
  is for hosts), with the reasoning recorded in a commit message
  (`72b99c63`) and the ledger.

## Issue tracker

- **Templates**: `ISSUE_TEMPLATE/bug_report.yml` is a YAML form with two
  required dropdowns that encode the repo's debugging cosmology —
  **Host** (all four + "not host-specific") and **"How far did it get?"**
  (`evaluation fails` / `build fails` / `switch-boot fails` / `runs but
  misbehaves` / `docs are wrong` — the rungs of lessons-learned §18), plus
  an optional `just threads <keywords>` field so filers check for known
  threads first. `config.yml`: blank issues disabled; contact link points
  at `wiki/README.md`.
- **Filing discipline** (AGENTS.md, enforced socially and by skill):
  `propose-issue` files only in this repo; upstream filing
  (nixpkgs, ble.sh, …) requires Elly's explicit, unprompted go-ahead —
  drafts live in `bugs pending submission/` with governance notes baked
  into each file. Caution: an issue body containing `owner/repo#123`
  autolinks and pings that repo, so anything filed here is grepped for
  that shape before naming an upstream issue.
- **De-duplication**: `just threads <term>` searches open issues + wiki +
  lessons-learned; skill `investigate-bug` makes it step 0.
- `wiki/open-threads.md` triages: GitHub-tracked issues vs pending
  upstream drafts vs loose todos.

## PR template

`PULL_REQUEST_TEMPLATE.md` — four headings: **What changed / Why /
Verified / Deliberately left alone**, with a comment noting `just
check`/`modules` are CI-enforced and the Verified section exists for what
CI cannot check (a real `just switch`, hardware behavior).

## Recommendations

- **R8 — pin `DeterminateSystems/nix-installer-action` by SHA in
  `check.yml`.** PR #204 pinned both actions in `update-flake-lock.yml` by
  full commit SHA specifically because pin-by-branch (@main) is mutable;
  `check.yml` still uses `@main`. It runs without write permissions, so
  the risk is lower — but the failure mode (upstream pushes a broken
  `main`, CI goes red repo-wide, nobody remembers why) is the same, and
  consistency is free.
- **R9 — enable "automatically delete head branches" in repo settings.**
  The ship flow deletes remote branches explicitly (and wants the local
  delete + checkout too, which the setting cannot do), but hand-merged
  PRs — e.g. the weekly lock PR, or anything merged from the web UI —
  leave their head branch behind; the ~25 stale `origin/*` branches
  include exactly such debris. The setting complements the flow rather
  than replacing it. (See also R7 for the existing debris.)
- **R10 (observation, no action required) — the zero-approval ruleset is
  the right call for a solo repo**, and the repo compensates with the
  one-combined-confirmation convention and "Verified" PR section. If a
  second maintainer ever appears, revisit: require one approval on
  `main`-promotion PRs only (hardware verification is currently
  self-attested in the promotion PR body).

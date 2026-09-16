# `lock-bump` — `config-system/homelab/lock-bump/`

_Last modified: 2026-09-16_

The weekly `flake.lock` bump, run by a timer on cube instead of a GitHub
Actions runner. Landed 2026-09-16 against [#205](https://github.com/NireBryce/nixos-configs/issues/205),
replacing `.github/workflows/update-flake-lock.yml` (deleted in the same
change). Structurally a copy of [backup](backup.md)'s shape: a timer, not a
listener — no port, no route, nothing to reach over the tailnet. Its own
`dirsAsCategory.nix`, cube-only, collected by the `homelab` umbrella like
the other nine.

## Contents

- [Why it moved off Actions](#why-it-moved-off-actions)
- [What the run does](#what-the-run-does)
- [The credential, and what is still manual](#the-credential-and-what-is-still-manual)
- [Imported by](#imported-by)
- [See also](#see-also)
## Why it moved off Actions

The runner could only **evaluate** a lock bump: `nix flake check + module
tree` forces each host's toplevel as an evaluation, and CI never builds it —
so an input bump that evaluates fine and breaks a host stays invisible until
someone runs `just switch` on real hardware. That is
[lessons-learned.md](../lessons-learned.md) §§36–37 exactly, and an input
bump is the change most likely to trip it. The timer's run does everything
the workflow did, plus the part the runner structurally could not: it
**builds nire-cube's toplevel on cube** before opening the PR.

What survives unchanged: the Monday 09:00 UTC slot, the
`update_flake_lock_action` branch name, the PR title and body, the
PAT-not-`GITHUB_TOKEN` reasoning (a PAT-opened PR triggers this repo's
`pull_request` workflows; a `GITHUB_TOKEN` one does not, and the
`experimental` ruleset requires them), and the loud-failure behaviour —
token preflight before any nix work, a 30-day expiry warning, and failure
notices landing as a reusable GitHub issue rather than a log line.

## What the run does

`flake/scripts/lock-bump.sh`, as `flake-lock-bump.service` /
`.timer` (module: `flake-lock-bump.nix`):

1. Preflights the token against the GitHub API (dead → hard fail before any
   nix work; ≤ 30 days from expiry → warn, continue, and exit non-zero at
   the very end so `OnFailure=` fires).
2. Refreshes a persistent clone in `/var/lib/flake-lock-bump/checkout`,
   resets `update_flake_lock_action` to `origin/experimental`.
3. `nix flake update`; exits cleanly ("nothing to propose") if the lock
   didn't move.
4. Preflight: `nix flake check --all-systems --no-build`, `modules.py
   check`, `lint.py check` — the same gate CI runs on the PR.
5. `nix build` of nire-cube's `system.build.toplevel` — the whole point.
6. Commits the lock (synthetic identity `nire-cube lock-bump`), force-pushes
   the branch, opens/updates the PR against `experimental`.

A fresh nixpkgs can make step 5 a real build; `TimeoutStartSec = 4h`. Most
weeks everything is substitutable and the run is minutes. Store growth from
accumulated toplevels is what `nix store gc` is for.

## The credential, and what is still manual

The PAT is the `flake-lock-token` key in `secrets.yaml`, decrypted to
`/run/secrets/flake-lock-token` on cube; expiry and rotation discipline is
[maintenance-schedule.md](../maintenance-schedule.md) item 10. **As of
2026-09-16 the value has not been minted yet** — the old Actions secret was
write-only, so the move needed a fresh PAT by definition. Until it is added:

- cube's next build/switch **fails at the sops manifest** (a declared secret
  with no value — the restic-cube-password failure mode). That is the
  designed loud prompt, not an accident.
- The timer, if it fires before then, fails at token preflight and the alert
  unit files the issue.

First-run checklist, in order:

1. Mint a fine-grained PAT (this repo; `Contents: read/write`,
   `Pull requests: read/write`), record its expiry in maintenance-schedule
   item 10, and `sops set` it into `secrets.yaml` as `flake-lock-token`
   from a session that can decrypt.
2. `just switch` cube (builds clean now), then
   `systemctl start flake-lock-bump` for an immediate first run, watched.
3. After that first success: revoke the old `FLAKE_LOCK_TOKEN` Actions
   secret (kept until then as the rollback path).

## Imported by

cube only — via the `homelab` umbrella aggregate in
`cube-configuration.nix`, same as the rest of `homelab/`'s nested
categories.

## See also

- [maintenance.md](../maintenance.md)'s "Lockfile updates" section — the
  user-facing run story.
- [maintenance-schedule.md](../maintenance-schedule.md) item 10 — the
  credential.
- [homelab.md](homelab.md) — the umbrella mechanism this nests under.
- Issue [#205](https://github.com/NireBryce/nixos-configs/issues/205) — why.

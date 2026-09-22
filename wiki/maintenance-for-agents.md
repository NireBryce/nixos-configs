# Fleet maintenance, for agents

_Last modified: 2026-09-22_

Condensed from [maintenance.md](maintenance.md). Credentials →
maintenance-schedule.md; backups → homelab/backup-runbook.md; one-time
setup → homelab/pending-setup.md; fleet history → history.md. Never
restated here.

## Lockfile updates

- `.github/workflows/update-flake-lock.yml`: cron `0 9 * * 1` (Mondays
  09:00 UTC) + `workflow_dispatch`; pushes branch
  `update_flake_lock_action`; opens PR `chore: update flake.lock` →
  `experimental`.
- The PR is a decision: review the lock diff, require green
  `nix flake check + module tree`, merge via skill `ship`. CI does not
  force a host toplevel for these; `just preflight` locally is stronger.
- Needs repo secret `FLAKE_LOCK_TOKEN` (fine-grained PAT) — expiry and
  rotation are maintenance-schedule.md item 10. Every run preflights the
  token, warns inside a 30-day expiry window, files issue
  `update-flake-lock: weekly lock PR needs attention` on failure/expiry —
  watch that issue, not the Actions log.
- Branch `update_flake_lock_action` ahead of `experimental` with no PR =
  the run pushed the lock, then PR creation failed (token missing/lapsed).
  Fix the cause, then re-run `workflow_dispatch` (reuses the branch), or
  open the PR by hand to `experimental`.
- By hand: `just update`.

## Deploying

- No auto-deploy, no remote builder, no binfmt: `just build` / `just
  boot` / `just switch` runs on the host itself. `just boot` for
  initrd/bootloader/impermanence changes — activates at next reboot;
  old generation stays in the boot menu.
- No fixed per-host cadence: hosts move when work targets them, plus
  merged lock PRs.
- Around every deploy: `just baseline` BEFORE switching (sudo; includes
  btrfs subvolumes; unrecoverable once the new generation boots and the
  store is collected) → `just fingerprint` and `just diff <ref>` (a moved
  drvPath says something changed; the diff says what) → `just
  diff-deployed` (package-level, running vs would-be) → `just
  hm-collisions` before a host's first switch → `just root-drift` (sudo;
  meaningful only where impermanence is imported: durandal and tenacity;
  cube deliberately keeps persistent root) → `just home-drift` (sudo;
  what neither /persist nor home-manager handles — pre-wipe audit for
  home).

## Store hygiene

- **Automatic, user profiles:** home-manager nh module
  `flake/modules/packages/nix-utils/nh/nh.nix` — `programs.nh.clean`
  enabled for elly on all four hosts (eval-verified per host,
  2026-09-14); systemd **user** timer `nh-clean.timer`, weekly Mondays
  00:00 local, `Persistent=true`, running `nh clean user --keep-since
  7d --keep 5` (read live on tenacity, 2026-09-14).
- **Manual, system profiles:** the user timer never touches root's
  profile — `sudo nh clean all --keep-since 7d --keep 5` (flags mirror
  the user unit; not exercised as root) or `sudo nix-collect-garbage
  -d`. Most relevant on nire-cube, the homelab service host.
- No disk-space watch configured anywhere in the tree; `df -h /` around
  a clean is the check.

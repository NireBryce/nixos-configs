# Fleet maintenance

_Last modified: 2026-09-25_

The fleet's recurring upkeep in one place: the weekly flake.lock PR,
deploying to a host and the verification habit around it, and store
hygiene — including which parts already run themselves, so a human does
only the parts that need a human. Opened as issue #295, whose candidate
list this page verified and filled in. **Credentials, keys, and
certificates are not here** — they are
[maintenance-schedule.md](maintenance-schedule.md)'s subject and stay
there.

> **Condensed version:**
> [maintenance-for-agents.md](maintenance-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [What lives here and what doesn't](#what-lives-here-and-what-doesnt)
- [Lockfile updates](#lockfile-updates)
- [Deploying, and the verification habit](#deploying-and-the-verification-habit)
- [Store hygiene](#store-hygiene)
- [The runner VM](#the-runner-vm)

## What lives here and what doesn't

Procedures that recur on a schedule or per-deploy. One fact per home —
this page links to the others rather than restating them:

- key and credential expiry, rotation, silent breakage →
  [maintenance-schedule.md](maintenance-schedule.md), tended by skill
  [`maintenance-schedule`](../.agents/skills/maintenance-schedule/SKILL.md)
- backups → [homelab/backup-runbook.md](homelab/backup-runbook.md)
- one-time pending setup →
  [homelab/pending-setup.md](homelab/pending-setup.md)
- what happened to the fleet, when, and how it was confirmed →
  [history.md](history.md)

## Lockfile updates

The dedicated page for this topic is [flake-lock.md](flake-lock.md).
The weekly PR: `.github/workflows/update-flake-lock.yml` runs Mondays
09:00 UTC (also on demand via `workflow_dispatch`), pushes the
`update_flake_lock_action` branch, and opens a PR titled
`chore: update flake.lock` against `experimental`.

The PR is a decision, not an auto-merge. This repo pins nixpkgs
deliberately — a lock bump can change what hosts build and boot,
including the hosts that wipe `/root` at every boot — so the lock diff
is the review: read it, confirm `nix flake check + module tree` went
green, and merge through the normal ship flow when the change is
wanted. CI does not force a host toplevel for these PRs, so `just
preflight` locally is the stronger check.

The workflow needs the `FLAKE_LOCK_TOKEN` repo secret — a fine-grained
PAT whose expiry and rotation belong to
[maintenance-schedule.md](maintenance-schedule.md) item 10, not here.
It preflights the token on every run, warns inside a 30-day expiry
window, and files an issue titled `update-flake-lock: weekly lock PR
needs attention` on any failure — that issue, not the Actions log, is
the thing to watch.

**Branch ahead, no PR attached** is the signature of a run that pushed
the lock but failed at PR creation (a missing or lapsed token). Fix the
cause first, then re-run the workflow (`workflow_dispatch` reuses the
branch), or open the PR by hand from `update_flake_lock_action` to
`experimental`.

By hand instead: `just update` — `nix flake update` for every input,
then `just check`.

## Deploying, and the verification habit

Nothing deploys itself. A host runs what this tree evaluates to only
after `just build` / `just boot` / `just switch` **on that host** —
there is no remote builder and no binfmt, so a NixOS host cannot be
built from another machine. Prefer `just boot` over `just switch` for
anything touching initrd, the bootloader, or impermanence: nothing
activates until the next deliberate reboot, and the running generation
stays in the boot menu as the fallback.

There is no fixed per-host cadence: hosts move when work targets them,
plus the weekly lock PR when it merges. The habit that wraps every
deploy matters more than any schedule:

- `just baseline` **before** switching — sudo, so the btrfs subvolumes
  are included. Everything it prints stops being recoverable once the
  new generation boots and the store is collected.
- `just fingerprint` before/after, and `just diff <ref>` when the
  drvPath moved — a moved hash says something changed; only the diff
  says what.
- `just diff-deployed` for the package-level diff between what is
  running and what would be installed.
- `just hm-collisions` before a host's first switch.
- `just root-drift` — what `/` carries that no persistence entry covers
  (sudo; meaningful only on the hosts that import impermanence:
  durandal and tenacity — cube deliberately keeps persistent root).
- `just home-drift` — what `/home` carries that neither a `/persist`
  entry nor home-manager is handling: real content a future home wipe
  would delete (sudo; the pre-wipe audit for home, meaningful on every
  host).

## Store hygiene

Half automatic, half not:

- **Automatic, user profiles.** The home-manager nh module
  (`flake/modules/packages/nix-utils/nh/nh.nix`) sets
  `programs.nh.clean` for elly on all four hosts (verified by eval on
  each host's config, 2026-09-14), which wires a systemd **user** timer:
  `nh-clean.timer` runs weekly, Mondays 00:00, `Persistent=true`, and
  executes `nh clean user --keep-since 7d --keep 5` — user-profile
  generations from the last 7 days (and at least 5) survive, older ones
  are collected. Timer and unit read live on tenacity, 2026-09-14.
- **Manual, system profiles.** The user timer never touches root's
  profile, so old **system** generations accumulate until collected by
  hand: `sudo nh clean all --keep-since 7d --keep 5` (same keep flags
  the user unit runs — not exercised as root), or
  `sudo nix-collect-garbage -d` for the blunter form. Most relevant on
  `nire-cube`, which runs the homelab services.
- No disk-space watch is configured anywhere in the tree. `df -h /`
  around a clean is the check.

## The runner VM

`forge-runner`, the libvirt guest on `nire-cube` that runs the Forgejo
Actions runner
([git-forge](categories/git-forge.md)), is `ephemeral` in the VM
generator's sense: its overlay qcow2 is thrown away and recreated from
the current base image on every cube boot, and on any switch that
changes the guest image or its domain XML. There is no periodic reset to
remember — a lock bump reaches the guest at the next `just switch` on
cube. The flip side: a switch that changes the guest kills a running job.

Before 2026-09-25 the overlay pinned its base at first creation and a
manual reset was the maintenance step. To force a reset by hand anyway
(the stamp lives on tmpfs, so removing it is enough):

```sh
# on nire-cube
sudo rm /run/libvirt-vm/forge-runner.stamp
sudo systemctl restart libvirt-vm-forge-runner   # destroys, recreates the overlay, defines + starts
```

What each reset costs: the guest's SSH host keys regenerate (update
`known_hosts`; the debug forward is `ssh -p 2223 root@ts-cube`, or
`ssh -J ts-cube root@192.168.122.11` from cube's side), and the guest nix
store's warm-up is lost (it refills from the cache on the next run).
Nothing else lives in the guest.

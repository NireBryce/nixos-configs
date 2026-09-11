# `backup`, for agents

_Last modified: 2026-09-11_

Condensed from [backup.md](backup.md), which keeps the investigation
narrative and the verification trail. Facts only here.

restic, backing up `nire-cube`'s service state to the QNAP NAS. Added
2026-08-28 against issue #87, nested under [homelab](homelab.md).
**Module is done** — restore drill performed twice, a real restore opened a
complete Forgejo database (2026-09-06).

## What's in it

One file, `nixos`-class: `restic/restic.nix`, declaring
`services.restic.backups.cube`.

Category isn't named `restic` because a category and its one module sharing
a name both declare `flake.modules.nixos.restic` and silently **merge** —
same reason `git-forge` isn't `forgejo`.

## Current shape

| | |
|---|---|
| Repository | `sftp:nire@ts-hive:/share/restic-backup/cube` |
| Auth | dedicated ed25519 key `~/.ssh/restic-cube-backup`, not the personal key |
| Host key | pinned in Nix via `programs.ssh.knownHosts`, not TOFU |
| sqlite staging | `/var/lib/restic-backups-cube-sqlite-staging` |
| Excluded | Prometheus TSDB (biggest, least valuable, regenerable); the three live sqlite db files |

## The two traps this module was built out of

- **restic silently refuses to back up anything inside its own
  `RESTIC_CACHE_DIR`** — nixpkgs sets that to
  `/var/cache/restic-backups-<name>`. The sqlite staging directory lived
  there and protected nothing for the module's entire life, with no error
  and green timers throughout. Proven by a `--dry-run` pair: 603 files with
  the variable unset, 600 with it set, nothing else changed. **Never stage
  anything under `/var/cache/restic-backups-*`.**
- **A green timer proves nothing about content.** The bar is a restore
  drill against the repository's own metadata: `restic ls --recursive
  <snapshot> <path>`, then an actual restore, then open the restored file.

## Not enforceable from this repo

Anti-deletion: cube's own credentials can `restic forget --prune` its
backups, and SFTP doesn't close that. The mitigation is a **QNAP-side
snapshot schedule on the `restic-backup` share** — admin console, nothing
here can enforce it. Confirmed live 2026-09-05: daily 04:30, keep 5 days.

QNAP SSH has no key-only-auth toggle; mitigated at the network level
instead — port 22 LAN-blocked, tailnet-only.

## Imported by

`nire-cube` only, via `homelab`. Confirmed not to move durandal, tenacity
or lysithea.

## See also

[backup.md](backup.md) ·
[../homelab/backup-runbook.md](../homelab/backup-runbook.md) (the actual
commands) · [../homelab/rustic.md](../homelab/rustic.md) ·
[backup-history.md](backup-history.md)

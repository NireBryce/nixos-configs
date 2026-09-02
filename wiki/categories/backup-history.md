# `backup` — history

## Contents

- [The original plan (2026-08-27)](#the-original-plan-2026-08-27)
- [The QNAP mount predates this category by months, and was never dangling](#the-qnap-mount-predates-this-category-by-months-and-was-never-dangling)
- [See also](#see-also)

Resolved incidents and superseded design behind [backup](backup.md) and
[../homelab/backup-runbook.md](../homelab/backup-runbook.md) — split out
2026-09-03 so those pages stay about the backend as it actually works today.
Nothing here changes what to type or how the module is shaped now.

## The original plan (2026-08-27)

Written before anything had touched cube or the QNAP for real, against
issue #87 and [homelab/pending-setup.md](../homelab/pending-setup.md) item
4. What it got wrong and what changed since:

- **What was at risk**, per issue #87 re-confirmed by grep 2026-08-27: cube
  has a plain persistent root, no impermanence, and nothing in `flake/`
  configured a backup tool. Four paths named explicitly: `/var/lib/forgejo`
  (repos, sqlite db, self-generated secrets), `/var/lib/grafana` (sqlite
  db — UI-created dashboards live only here), `/var/lib/private/golink`
  (links db + tsnet node key), `/persist/secrets/`/`/persist/passwords/`
  (hand-created, nothing recreates them). None recoverable if lost.
  Prometheus's TSDB was deliberately excluded from the start — biggest
  path, least valuable, fully regenerable by scraping again.
- **The six-step shape it proposed**: size the paths first (`du -sh`)
  before committing to a retention policy — still not done, see [backup](backup.md)'s
  "What isn't done yet"; import the storage mount; confirm the QNAP side (a
  share plus a native snapshot schedule, the anti-deletion mitigation); a
  new cube-only category wrapping `services.restic.backups.cube` with a
  sops-secret password and a `backupPrepareCommand` staging sqlite copies;
  a repo password kept outside cube too, since the sops key needed to
  decrypt it lives on cube's own disk; and a restore drill as the actual
  bar for done — a definition that outlived the plan itself and is still
  how #87 and the runbook define "done."
- **The one judgment call it flagged explicitly**, rather than presenting
  as settled: NFS-local-path trades keyed auth for not standing up SSH on
  the QNAP at all. That's the trade-off that broke in practice — see
  [backup](backup.md)'s SFTP section.

Lived at `claude cave/plans/2026-08-27-1816-cube-qnap-backup-plan.md`
until 2026-09-02, then folded into `backup-runbook.md`'s own "Background"
section when `claude cave/` was retired; moved here 2026-09-03.

## The QNAP mount predates this category by months, and was never dangling

The plan doc above described `nire/system/storage/storage-NFS.nix` (the
NFS mount to the QNAP) as an unused module. It isn't:
`nire/system/storage/` has no `dirsAsCategory.nix` of its own, so the
module is collected straight into the shared `system` aggregate, which
every Linux host imports — confirmed via `nix eval
.#nixosConfigurations.<host>.config.fileSystems` on all three NixOS hosts,
2026-08-28. So no new import was needed to reach it. Still true from the
plan: nothing had ever exercised that mount against the real QNAP, so
"already imported" ≠ "known to work."

The mount point itself moved 2026-08-28: `/mnt/qnap-erin` (a share shared
with unrelated QNAP uses) → `/mnt/restic-backup` (dedicated). As of
2026-08-31 the module doesn't use that mount at all — see [backup](backup.md)'s
SFTP section — but `storage-NFS.nix` is untouched, still there for
whatever else wants it.

## See also

- [backup](backup.md) — the category as it actually works today.
- [../homelab/backup-runbook.md](../homelab/backup-runbook.md) — the
  commands.
- [../open-threads.md](../open-threads.md) — issue #87.

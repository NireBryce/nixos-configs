# `backup` — `nire/homelab/backup/`

_Last modified: 2026-09-11_

## Contents

- [What's in it](#whats-in-it)
- [Why the category isn't named `restic`](#why-the-category-isnt-named-restic)
- [SFTP repository now, not local-path on NFS](#sftp-repository-now-not-local-path-on-nfs)
- [The sqlite consistency bug — root-caused and fixed, 2026-09-06](#the-sqlite-consistency-bug--root-caused-and-fixed-2026-09-06)
- [What's excluded, and why](#whats-excluded-and-why)
- [Anti-deletion is not a Nix change](#anti-deletion-is-not-a-nix-change)
- [What isn't done yet](#what-isnt-done-yet)
- [Imported by](#imported-by)
- [See also](#see-also)

> **Condensed version:**
> [backup-for-agents.md](backup-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

[restic](https://restic.net/), backing up `nire-cube`'s own service state to
the QNAP NAS already on the network. Added 2026-08-28, cube-only, against
issue [#87](https://github.com/NireBryce/nixos-configs/issues/87) ("no
backups anywhere in the fleet"). The original plan, an early NFS-mount
correction, and the mount's own pre-history are on
[backup-history.md](backup-history.md).

Nested under [homelab](homelab.md) the same way the other seven are — see
that page's own note on this one being the odd member out functionally
(nothing to reach over the tailnet; a timer, not a listener) but structurally
identical.

## What's in it

One file, `nixos`-class: `restic/restic.nix`, declaring
`services.restic.backups.cube`.

## Why the category isn't named `restic`

Same reason [git-forge](git-forge.md) isn't `forgejo` and
[shortlinks](shortlinks.md) isn't `golink`: a category and its one module
both named `restic` would both declare `flake.modules.nixos.restic` and
silently **merge** — the `containers`/`podman.nix` collision
[architecture.md](../architecture.md) documents.

## SFTP repository now, not local-path on NFS

Shipped 2026-08-28 with a local-path repository on the NFS mount, a
deliberate departure from #87's original SFTP sketch (restic encrypts
client-side regardless of backend, so local-path gets the same
encryption-at-rest without SSH on the QNAP). The stated trade-off — NFS
export trust is IP-based, not keyed — is what broke it: a real switch hit
`mount.nfs: access denied by server`, the share's host-access list never
got cube added, and the QNAP admin console has no way to force key-only
SSH anyway. So: issue #87's original plan, SFTP — real per-connection key
auth rather than a host-IP allowlist.

The module now points at `sftp:nire@ts-hive:/share/restic-backup/cube`,
authenticating with a dedicated ed25519 key (generated for this, not the
personal key; confirmed by hand: `ssh -i ~/.ssh/restic-cube-backup
nire@ts-hive` authenticates with no password). The QNAP host key is pinned
in Nix (`programs.ssh.knownHosts` via `ssh-keyscan`), not trusted on first
connection.

**Moved off `nire`'s home 2026-09-03** — it originally pointed at
`/share/homes/nire/restic-cube`, but QNAP snapshots the anti-deletion
mitigation below needs are per-shared-folder, so that path would have
required snapshotting every user's home directory just to cover this repo.
`restic-backup` (Storage Pool 2) already exists as its own unused share, so
the repo moved there. **Done, live-confirmed 2026-09-05**: cube switched
onto this path, its own timer already ran successfully against it, and the
five snapshots from the old `homes` path (2026-08-31 through 2026-09-04)
were migrated in with `restic copy` — six snapshots total, verified via a
live `snapshots` listing. See [backup-history.md](backup-history.md) for
exactly what ran.

## The sqlite consistency bug — root-caused and fixed, 2026-09-06

Forgejo, Grafana and golink are all sqlite, and copying a live db file can
capture a torn write mid-transaction that restic will store without
complaint (issue #87's open question 1). `backupPrepareCommand` runs
`sqlite3 <db> ".backup"` into a staging directory before each backup; the
three live db files are `exclude`d, so it's the staged, consistent copy
that actually gets backed up, not the live one.

**It had never worked.** Found doing the restore drill this page's own
"done means" always said was the real bar: `restic ls --recursive
<snapshot> /var/cache/restic-backups-cube/sqlite-staging` against the
repository's own metadata — not a restore, the repository directly —
showed **zero file entries** in every real snapshot checked: 2026-09-01,
2026-09-05, and two fresh on-demand runs on 2026-09-06, one immediately
after a full reboot of cube. `/persist/secrets`, `/persist/passwords`,
and the live Forgejo/Grafana/golink directories really were backed up;
only this specific mechanism — the entire reason `backupPrepareCommand`
exists — had silently protected nothing, the whole time.

**Root cause**: the staging directory lived at
`/var/cache/restic-backups-cube/sqlite-staging` — *inside*
`RESTIC_CACHE_DIR` (nixpkgs' restic module sets that to
`/var/cache/restic-backups-<name>`, matching the systemd unit's own
`CacheDirectory=` exactly). **restic refuses to back up its own cache
directory.** Confirmed with a clean before/after test, not from docs: the
identical `restic backup --dry-run` with the identical
`--exclude-file`/`--files-from` processed 603 files (all three staged
sqlite copies included) with `RESTIC_CACHE_DIR` unset, and exactly 600
(all three silently dropped, no error) with it set to the real value —
the one variable that changed. Everything else chased along the way and
ruled out, each by faithful reproduction rather than inference: sandboxing
(`PrivateTmp`/`CacheDirectory`, via `systemd-run` with matching
properties); exclude-pattern basename matching; switch-without-reboot
cruft (survived a fresh reboot). A `backupPrepareCommand`-added diagnostic
log (`prepare.log`) proved the sqlite3 step itself always wrote real,
correctly-sized files — the failure was 100% on restic's side.

**Fix**: `sqliteStagingDir` moved to `/var/lib/restic-backups-cube-sqlite-staging`
— outside the cache directory entirely, a structural fix rather than an
`--exclude-caches`-adjacent flag that would leave the directory choice
still wrong.

**What this means for existing backups**: every snapshot taken before
this fix protects `/persist/secrets`, `/persist/passwords`, and the live
service directories, but not the sqlite databases themselves — nothing
past-tense is recoverable that wasn't already.

**Confirmed live, 2026-09-06 — issue #87's actual "done means" bar,
finally met for real.** Cube switched, a real run produced snapshot
`095beb8e` with `/var/lib/restic-backups-cube-sqlite-staging` correctly
listing all three real files, and a real restore of that path opened a
genuine, complete Forgejo database — every expected table present
(`repository`, `user`, `issue`, `pull_request`, `webhook`, `action_run`,
and dozens more). Not just "backed up": recovered, and openable. This is
the first time since the module's creation that's been true.

## What's excluded, and why

Prometheus's TSDB is deliberately not in `paths` — issue #87's open
question 4: the biggest path on the host by far, the least valuable, and
fully regenerable by scraping again. Nothing else cube runs is excluded.

## Anti-deletion is not a Nix change

Issue #87's open question 3: anything compromising cube can run
`restic forget --prune` against its own backups, since `nire` (the QNAP
account) has full read-write access to the repository. SFTP didn't close
this. The mitigation this module assumes — cheapest rung of #87's
ascending-effort list — is a **QNAP-side native snapshot schedule on the
`restic-backup` share itself** (the repo's own dedicated share as of
2026-09-03, not a share shared with anything else), so cube can write and
prune within the repository but can't touch the NAS's own snapshots. QNAP
admin-console configuration, so nothing in this repo can enforce it — but
**confirmed live, 2026-09-05**, via a Snapshot Manager screenshot: daily
at 04:30, keeping 5 days, status Success, 2 snapshots taken.

## What isn't done yet

Live-checked 2026-09-05/06, over ssh to `nire-cube.local`:

- ~~Both sops secrets are declared but this tree can't set their
  values~~ — **set, 2026-08-30/31**, and the shell-level mechanics work:
  real timer runs exit `status=0/SUCCESS` end to end against both the old
  and new repo paths. **Whether the content they produce is actually
  correct is a separate question** — see "The sqlite consistency bug"
  above.
- ~~The repository path moved but cube hasn't switched onto it~~ —
  **switched, and the pre-move repo's history migrated in** (see above).
- ~~The QNAP-side snapshot schedule described above still hasn't been
  configured~~ — **done** (see above).
- ~~The sqlite consistency bug — root cause unknown~~ — **root-caused,
  fixed, and confirmed live** (above): a real restore of the new path
  opened a genuine, complete Forgejo database.
- **SSH's own exposure is mitigated, as of 2026-08-31** — QuTS hero has no
  toggle to force key-only auth, so this was done at the network level
  instead: port 22 is LAN-blocked and tailnet-only (confirmed live from
  both lysithea and cube — the LAN address times out, `ts-hive`'s tailnet
  address still connects), and QNAP's own brute-force protection is on
  (taken on confirmation, not independently checked). See
  [backup-history.md](backup-history.md) for the full account.

All of the above is genuinely done. The restore drill has genuinely been
performed — issue #87's own "done means" was followed exactly as
written, twice: once to find that the sqlite consistency mechanism
(above) had never worked, something no green timer ever would have
caught, and once more after the fix, to confirm a real restore recovers
a real, openable Forgejo database. **This module is done.**

## Imported by

`nire-cube` only, via `homelab`. Confirmed not to move durandal, tenacity,
or lysithea: each host's toplevel `drvPath` is byte-identical before and
after this category was added.

## See also

- [homelab](homelab.md) — the umbrella category this nests under.
- [git-forge](git-forge.md), [monitoring](monitoring.md),
  [shortlinks](shortlinks.md) — the three services this category actually
  backs up.
- [../open-threads.md](../open-threads.md) — "Left open by the cube service
  stack", where issue #87 was first tracked.
- [../homelab/pending-setup.md](../homelab/pending-setup.md) — the two
  remaining human steps, alongside the fleet's other one-time setup.
- [../homelab/backup-runbook.md](../homelab/backup-runbook.md) — the actual
  commands (finishing setup, status, manual backup, restore).
- [../homelab/rustic.md](../homelab/rustic.md) — an interactive TUI that can
  browse and restore from this same repository, installed but not yet
  switched or run against it.
- [backup-history.md](backup-history.md) — the original plan and what it
  got wrong about the QNAP mount.

# `backup` — `nire/homelab/backup/`

## Contents

- [What's in it](#whats-in-it)
- [Why the category isn't named `restic`](#why-the-category-isnt-named-restic)
- [SFTP repository now, not local-path on NFS](#sftp-repository-now-not-local-path-on-nfs)
- [sqlite consistency](#sqlite-consistency)
- [What's excluded, and why](#whats-excluded-and-why)
- [Anti-deletion is not a Nix change](#anti-deletion-is-not-a-nix-change)
- [What isn't done yet](#what-isnt-done-yet)
- [Imported by](#imported-by)
- [See also](#see-also)

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
the repo moved there. **Live-checked 2026-09-04**: cube is still running
the pre-move build (`RESTIC_REPOSITORY` on the live unit is still the old
`homes` path) — and that path has real data in it: the 2026-09-03 timer
run succeeded, so there's a working repo with a real snapshot that needs
migrating before cube switches, not abandoning. See
`wiki/homelab/backup-runbook.md`'s step 4 for the migration command;
`nire`'s write access to `restic-backup` itself is still unconfirmed.

## sqlite consistency

Forgejo, Grafana and golink are all sqlite, and copying a live db file can
capture a torn write mid-transaction that restic will store without
complaint (issue #87's open question 1). `backupPrepareCommand` runs
`sqlite3 <db> ".backup"` into a staging directory
(`/var/cache/restic-backups-cube/sqlite-staging`) before each backup; the
three live db files are `exclude`d, so it's the staged, consistent copy that
actually gets backed up, not the live one.

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
admin-console configuration; nothing in this repo can enforce or verify it.

## What isn't done yet

Live-checked 2026-09-04, over ssh to `nire-cube.local`:

- ~~Both sops secrets are declared but this tree can't set their
  values~~ — **set, 2026-08-30/31**, and **confirmed working**: the
  2026-09-03 backup timer run succeeded end to end
  (`restic-backups-cube.service`, `status=0/SUCCESS`), the first real
  proof of that, not just an evaluated config.
- **The repository path moved** (2026-09-03) but cube hasn't switched onto
  it yet — the running unit still targets the old `homes` path. That old
  path now has a real, working repo in it that needs migrating rather than
  starting fresh (see above and the runbook's step 4) before this switch
  happens.
- **The QNAP-side snapshot schedule** described above still hasn't been
  configured.
- **SSH's own exposure is mitigated, as of 2026-08-31** — QuTS hero has no
  toggle to force key-only auth, so this was done at the network level
  instead: port 22 is LAN-blocked and tailnet-only (confirmed live from
  both lysithea and cube — the LAN address times out, `ts-hive`'s tailnet
  address still connects), and QNAP's own brute-force protection is on
  (taken on confirmation, not independently checked). See the runbook's
  setup step 3 for the full account.

Even once all of that's done, this module still isn't done — per issue
#87's own "done means": a **restore actually performed** — one Forgejo repo
recovered and confirmed to open — is the bar, not a working connection or
even a real backup running once.

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

# `backup` — `nire/homelab/backup/`

[restic](https://restic.net/), backing up `nire-cube`'s own service state to
the QNAP NAS already on the network. Added 2026-08-28, cube-only, against
issue [#87](https://github.com/NireBryce/nixos-configs/issues/87) ("no
backups anywhere in the fleet") and the plan at
[`claude cave/plans/2026-08-27-1816-cube-qnap-backup-plan.md`](<../../claude cave/plans/2026-08-27-1816-cube-qnap-backup-plan.md>).

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

## The QNAP mount predates this category by months, and was never dangling

The plan doc this category implements got one thing wrong, corrected while
writing the module rather than left to rot: it described
`nire/system/storage/storage-NFS.nix` (the NFS mount to the QNAP) as an
unused module nobody had wired into any host. It isn't.
`nire/system/storage/` has no `dirsAsCategory.nix` of its own, so that
module is collected straight into the shared `system` aggregate
([architecture.md](../architecture.md) covers this mechanism generally) —
and every Linux host imports `system`. `nix eval
.#nixosConfigurations.<host>.config.fileSystems` on all three NixOS hosts
already listed the mount, checked 2026-08-28. So it was already live
everywhere; this category needed no new import to reach it. What's still
true from the original plan: nothing in this repo has ever exercised that
mount against the real QNAP, so "already imported" is not the same claim as
"known to work."

**The mount point itself moved, same day.** Originally `/mnt/qnap-erin`
(device `192.168.0.200:/erin-pub`), a share shared with other, unrelated
QNAP uses; renamed to `/mnt/restic-backup` (device
`192.168.0.200:/restic-backup`), a share dedicated to this category —
`storage-NFS.nix`'s own header is the current source of truth. This page
and the module both reflect the new path.

## Local-path repository, not SFTP

Issue #87's original sketch was restic over SFTP to the QNAP. This module
uses a local-path repository instead — `/mnt/restic-backup/cube` (`cube` is
a host-scoped subdirectory in case another host gets its own backup
category later) — because restic encrypts client-side regardless of
backend, so a local-path repo gets the same encryption-at-rest #87 wanted
from SFTP without standing up SSH, a restricted backup user, or
`rest-server`/Container Station on the QNAP side at all.

This is the one real trade-off in the module, not a settled fact: NFS export
trust is IP-based rather than keyed, so anything on the LAN with the right
IP can mount the share. It's compensated for, not eliminated — see
"Anti-deletion" below — and less exposed than under the old shared
`erin-pub` export, now that this lives on a share dedicated to backups.

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

Issue #87's open question 3: anything that compromises or wipes cube can run
`restic forget --prune` against its own backups, since cube has full
read-write access to the NFS export. The mitigation this module assumes —
cheapest rung of the ascending-effort list #87 proposes — is a **QNAP-side
native snapshot schedule on the `restic-backup` share**, so cube can write
and prune within the restic repository but can't touch the NAS's own
snapshots.
That's QNAP admin-console configuration, not something this module (or
anything in this repo) can enforce or verify.

## What isn't done yet

Smaller than it looked partway through, as of 2026-08-29:

- **The repository password now has a value — but it's uncommitted.** Set
  via `sops set` against a separate checkout on cube itself
  (`~/projects/nix/nixos-configs`), not from this tree. sops-nix validates
  its secrets manifest as part of the *build*, not only at activation, so
  this was a real blocker until found: a first `just build` on cube (synced
  over ssh, since darwin can't cross-build `x86_64-linux`) failed exactly
  there —
  `sops-install-secrets: ... the key 'restic-cube-password' cannot be
  found` — because the session that wrote this module never had decrypt
  access to set it. What that first attempt didn't know is that the secret
  already existed, just in a checkout it hadn't looked at. Merging that
  checkout's `secrets.yaml` into the tree and rebuilding: a clean full
  `system.build.toplevel`, `restic`/`restic-cube`/`rustic` all present.
  **Committing that `secrets.yaml` edit — safe, it's ciphertext, this repo
  commits `secrets.yaml` encrypted deliberately — is the remaining step**,
  not generating a new value.
- **The QNAP-side snapshot schedule** described above hasn't been
  configured — this repo has no way to reach into the QNAP's admin console.

Once the secret is committed and a real `switch` has run on cube, this
module still isn't done — per issue #87's own "done means": a **restore
actually performed** — one Forgejo repo recovered and confirmed to open —
is the bar, not a green timer or even a clean build.
[homelab/backup-runbook.md](../homelab/backup-runbook.md) is the
step-by-step procedure for what's left.

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
  commands: finishing setup, checking status, running a backup by hand, and
  performing a restore.
- [../homelab/rustic.md](../homelab/rustic.md) — an interactive TUI that can
  browse and restore from this same repository, installed but not yet
  switched or run against it.
- [`../../claude cave/plans/2026-08-27-1816-cube-qnap-backup-plan.md`](<../../claude cave/plans/2026-08-27-1816-cube-qnap-backup-plan.md>)
  — the plan this category implements, including what it got wrong about
  the QNAP mount's status.

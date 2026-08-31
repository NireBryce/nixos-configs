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

**The mount point itself moved, 2026-08-28.** Originally `/mnt/qnap-erin`
(device `192.168.0.200:/erin-pub`), a share shared with other, unrelated
QNAP uses; renamed to `/mnt/restic-backup` (device
`192.168.0.200:/restic-backup`), a share dedicated to this category. **As
of 2026-08-31 this module no longer uses that mount at all** — see the next
section — but `storage-NFS.nix` itself is untouched and still exists for
whatever else might want it.

## SFTP repository now, not local-path on NFS

This module shipped 2026-08-28 with a local-path repository on the NFS
mount above, a deliberate departure from issue #87's original sketch of
restic over SFTP — the reasoning at the time: restic encrypts client-side
regardless of backend, so a local-path repo gets the same encryption-at-rest
without standing up SSH on the QNAP at all. Stated then as the one real
trade-off: NFS export trust is IP-based, not keyed, so anything on the LAN
with the right IP could mount the share.

**That trade-off is what broke it.** A real switch on cube hit `mount.nfs:
access denied by server` — the `restic-backup` share's NFS host-access list
never got cube added. Chasing that down (and finding the QNAP's own admin
console has no way to force key-only SSH, so the NFS route wasn't even the
weaker option by much) led to just doing what issue #87 originally
suggested: enable SSH on the QNAP and use SFTP directly. Real per-connection
key auth, not a host-IP allowlist — better on the exact axis that failed.

The module now points at `sftp:nire@ts-hive:/share/homes/nire/restic-cube`,
authenticating with a dedicated ed25519 key (generated on cube specifically
for this, not the personal key that already had interactive QNAP access —
confirmed working by hand: `ssh -i ~/.ssh/restic-cube-backup nire@ts-hive`
authenticates with no password). The QNAP's host key is pinned in Nix
(`programs.ssh.knownHosts`, captured via `ssh-keyscan` against the real
host) rather than trusted on first connection at runtime.

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
`restic forget --prune` against its own backups, since `nire` (the QNAP
account restic authenticates as) has full read-write access to
`~/restic-cube`. Switching from NFS to SFTP didn't close this — the
mitigation this module still assumes, unchanged, cheapest rung of the
ascending-effort list #87 proposes — is a **QNAP-side native snapshot
schedule on the `restic-backup` share** (`nire`'s home lives under it), so
cube can write and prune within the restic repository but can't touch the
NAS's own snapshots. That's QNAP admin-console configuration, not something
this module (or anything in this repo) can enforce or verify.

## What isn't done yet

As of 2026-08-31: SSH now works on the QNAP, the dedicated key
authenticates, and the module points at the SFTP repository — but nothing
has actually confirmed a real backup works end to end yet.

- **Both sops secrets are declared but this tree can't set their values.**
  `restic-cube-password` (the repository password) and the new
  `restic-cube-ssh-key` (the dedicated SSH private key, currently sitting
  as a plain file on cube at `~/.ssh/restic-cube-backup`) both need real
  decrypt access to `secrets.yaml`, which the session that wrote this
  switch didn't have. See the module's own header for the exact commands.
  A real build on cube confirmed the *shape* of the resulting failure for
  the new key — the same build-time `sops-install-secrets` failure the
  password hit originally — and confirmed everything else (21 other
  derivations, including `home-manager-generation`) builds clean around it.
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
  commands: finishing setup, checking status, running a backup by hand, and
  performing a restore.
- [../homelab/rustic.md](../homelab/rustic.md) — an interactive TUI that can
  browse and restore from this same repository, installed but not yet
  switched or run against it.
- [`../../claude cave/plans/2026-08-27-1816-cube-qnap-backup-plan.md`](<../../claude cave/plans/2026-08-27-1816-cube-qnap-backup-plan.md>)
  — the plan this category implements, including what it got wrong about
  the QNAP mount's status.

# `backup` — `nire/homelab/backup/`

## Contents

- [What's in it](#whats-in-it)
- [Why the category isn't named `restic`](#why-the-category-isnt-named-restic)
- [The QNAP mount predates this category by months, and was never dangling](#the-qnap-mount-predates-this-category-by-months-and-was-never-dangling)
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
backups anywhere in the fleet") and an original plan, folded into
[`../homelab/backup-runbook.md`](<../homelab/backup-runbook.md>)'s
"Background" section 2026-09-02 when `claude cave/` was retired.

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

The plan doc this category implements described
`nire/system/storage/storage-NFS.nix` (the NFS mount to the QNAP) as an
unused module. It isn't: `nire/system/storage/` has no `dirsAsCategory.nix`
of its own, so the module is collected straight into the shared `system`
aggregate, which every Linux host imports — confirmed via `nix eval
.#nixosConfigurations.<host>.config.fileSystems` on all three NixOS hosts,
2026-08-28. So no new import was needed to reach it. Still true from the
plan: nothing had ever exercised that mount against the real QNAP, so
"already imported" ≠ "known to work."

The mount point itself moved 2026-08-28: `/mnt/qnap-erin` (a share shared
with unrelated QNAP uses) → `/mnt/restic-backup` (dedicated). **As of
2026-08-31 this module doesn't use that mount at all** — next section — but
`storage-NFS.nix` is untouched, still there for whatever else wants it.

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

The module now points at `sftp:nire@ts-hive:/share/homes/nire/restic-cube`,
authenticating with a dedicated ed25519 key (generated for this, not the
personal key; confirmed by hand: `ssh -i ~/.ssh/restic-cube-backup
nire@ts-hive` authenticates with no password). The QNAP host key is pinned
in Nix (`programs.ssh.knownHosts` via `ssh-keyscan`), not trusted on first
connection.

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
account) has full read-write access to `~/restic-cube`. SFTP didn't close
this. The mitigation this module assumes — cheapest rung of #87's
ascending-effort list — is a **QNAP-side native snapshot schedule on the
`restic-backup` share** (`nire`'s home lives under it), so cube can write
and prune within the repository but can't touch the NAS's own snapshots.
QNAP admin-console configuration; nothing in this repo can enforce or
verify it.

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
  commands (finishing setup, status, manual backup, restore); its
  "Background" section is the plan this category implements, folded in
  there 2026-09-02 including what it got wrong about the QNAP mount.
- [../homelab/rustic.md](../homelab/rustic.md) — an interactive TUI that can
  browse and restore from this same repository, installed but not yet
  switched or run against it.

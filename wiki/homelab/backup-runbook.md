# Backup runbook — restic on `nire-cube`

Operating [backup](../categories/backup.md) — the restic category that backs
up Forgejo/Grafana/golink's state and `/persist` to the QNAP NAS. That page
covers *why* it's shaped this way; this page is *what to actually type*, on
`nire-cube`, to finish setting it up, run it, check it, and restore from it.

**Status as of 2026-08-30: switched and running on cube, blocked on one QNAP
setting.** `restic-backups-cube.service`/`.timer` are live on cube's actual
running system (confirmed by `readlink /run/current-system` matching the
toplevel `~/projects/nix/nixos-configs` at its current commit evaluates
to), `rustic`/`restic-cube` are both on `elly`'s real `$PATH`, and the
secret is in place. The one thing standing between this and a working
backup: **the NFS mount fails with `mount.nfs: access denied by server`**,
a QNAP export-permissions problem, not a Nix problem — see "The current
blocker" below before anything else on this page. SSH into the QNAP itself
was attempted and isn't available (see that section too), so this needs the
QNAP's own web admin console, not a shell.

Earlier state, for context on how this was found: a real `just build` on
cube (synced over ssh, twice, since darwin can't cross-build
`x86_64-linux`) first failed with `sops-install-secrets` unable to find
`restic-cube-password` — a **build-time** failure, not just a runtime one —
because that attempt was built from a `secrets.yaml` that didn't have it
yet. The password had already been set elsewhere on cube
(`~/projects/nix/nixos-configs`); merging that in fixed the build. Since
then the secret's been committed, cube's been switched (not by an agent
session — `sudo` there needs a password an ssh session doesn't have), and
the NFS problem below is what actually surfaced once the switch made the
automount unit real.

## The current blocker: the QNAP is refusing the NFS mount

Real error, from cube's own journal (`journalctl -u "mnt-restic*"`), the
moment the switch made `mnt-restic\x2dbackup.automount` a real unit and
something (`ls /mnt/restic-backup`) triggered it:

```
mount.nfs: access denied by server while mounting 192.168.0.200:/restic-backup
```

Not a client-side problem — the `nfs`/`nfsv4` kernel modules are loaded
(`lsmod` confirms it), the automount unit itself is set up correctly, and
the QNAP answers pings and its admin web ports (443, 8080) fine. `access
denied by server` is NFS's own wording for the *server* rejecting the
mount, which for QNAP almost always means the share's NFS host-access list
doesn't include the client yet — plausible here specifically because
`restic-backup` is a **new, dedicated share** (renamed 2026-08-28 from a
share that had other, already-permitted uses), so it likely never got an
access rule for cube at all.

**Fix, on the QNAP's own admin console** (not verified against the actual
menu — flag this the way the rest of this page flags untested steps):
Control Panel → Shared Folders → `restic-backup` → NFS permissions (or
wherever QTS keeps per-share NFS host rules) → add `nire-cube`'s IP, or
"No limit" if that's an acceptable trust level for a share nothing else
uses. Re-trigger with `ls /mnt/restic-backup` from cube after saving.

**SSH into the QNAP was tried and doesn't work, so this can't be done from
a terminal.** Checked from both the LAN (`192.168.0.200:22`) and the
tailnet (`ts-hive:22`): the LAN attempt times out (filtered, not
refused — consistent with the port simply not listening rather than an
active reject), and tailnet gives an explicit `Connection refused`. Telnet/
SSH is very likely just switched off in QTS's own Network & File Services
settings, which is the QNAP default — nothing wrong on cube's end to fix
here. If shell access to the QNAP is ever wanted, that's a separate,
explicit step in that same settings page, not something this repo or an ssh
key can turn on remotely.

## Before any of this works: two setup steps, once each

Both are also tracked in [Pending setup](pending-setup.md) item 4; this is
the actual procedure, not just the tracking entry. **Step 1 and step 3 are
done; step 2 (the QNAP snapshot schedule) is still open**, separate from
the NFS access problem above — nothing has confirmed it's configured.

### 1. Set the repository password

**Already done, 2026-08-29 — but not committed.** Set via `sops set`
against `~/projects/nix/nixos-configs` on cube, confirmed present there and
confirmed (by a real `just build`) to make cube's toplevel build cleanly.
What's actually left is committing that `secrets.yaml` from wherever it
lives — safe to do, it's ciphertext, and this repo commits `secrets.yaml`
encrypted on purpose (`AGENTS.md`, Safety section).

The command below is for the record — how it was set, and what to run again
if this password ever needs rotating rather than just committing what
already exists. Needs real decrypt access to `secrets.yaml` — one of the age
keys enrolled in `.sops.yaml` (durandal, lysithea, tenacity, or cube's own
host key). From a session/host that has one, from the repo root:

```sh
nix shell nixpkgs#sops nixpkgs#age --command \
    sops set flake/modules/nire/system/secrets/secrets.yaml \
    '["restic-cube-password"]' \
    "\"$(openssl rand -base64 32)\""
```

The value is generated inline via command substitution, so it's never a
literal in the command text or in anything that echoes the command back —
see `.claude/skills/secrets-hygiene/SKILL.md` if running this from an agent
session.

**Losing this password loses the backups.** restic has no recovery path for
a forgotten repository password — write it down somewhere that isn't cube
and isn't this repo (a password manager), the same "outside the backup"
concern issue #87 raised for exactly this reason.

### 2. Configure a QNAP-side snapshot schedule on the backup share

The anti-deletion mitigation: cube can write and prune within the restic
repository (`/mnt/restic-backup/cube`) but shouldn't be able to erase the
NAS's own snapshots of it. `restic-backup` is already a share dedicated to
this alone (renamed 2026-08-28 from a generic share used for other things
too), so — unlike issue #87's original ascending-effort list, which treated
a dedicated share as a fallback if per-folder scoping wasn't available —
there's no scoping decision left to make: the schedule below covers the
whole share, and the whole share is this backup's. **This page has not
verified the QNAP's actual menu layout** — QTS versions move things — so
treat the following as a starting point to confirm against the real admin
console, not a copy-paste procedure:

1. QNAP admin console → Control Panel → Storage & Snapshots (or the
   snapshot manager for the volume the `restic-backup` share lives on).
2. Find or create a scheduled snapshot job for the `restic-backup` share.
3. A daily schedule with a few days/weeks of retention is enough to recover
   from an accidental or malicious `restic forget --prune`; it doesn't need
   to match restic's own retention.

If the QNAP's snapshot granularity is coarser than a single share (whole
volume only), the remaining fallback from issue #87's list is
`restic-rest-server` in append-only mode, if the QNAP has Container Station.

### 3. Switch cube

**Done, 2026-08-30.** `readlink /run/current-system` on cube matches
`~/projects/nix/nixos-configs`'s current-commit toplevel exactly (checked
with `nix eval --raw
.#nixosConfigurations.nire-cube.config.system.build.toplevel`) — this
wasn't an agent session doing it (`sudo` on cube needs a password an ssh
session doesn't have, per `AGENTS.md`'s Commands section), it had already
happened by the time one went looking.

**One checkout trap worth knowing about**: cube has *two* clones of this
repo, `~/nixos-configs` (stale — still several commits behind as of this
writing) and `~/projects/nix/nixos-configs` (the one that's actually
current and actually running). Check which one you're in before trusting
its `git log`, the same lesson the module's own header carries about the
secret living in the "other" checkout the first build attempt didn't know
about.

```sh
cd ~/projects/nix/nixos-configs && git pull && just switch
```

## Checking status

```sh
systemctl status restic-backups-cube.service
systemctl list-timers restic-backups-cube.timer
journalctl -u restic-backups-cube -e
```

The timer fires daily at 03:30 plus up to a 30-minute random delay
(`timerConfig` in `restic.nix`) — `list-timers` shows the next scheduled run
without waiting for it.

**Real output, 2026-08-30**, for what "working so far" actually looks like
(the service hasn't run yet — the NFS blocker above means it would fail if
it did):

```
$ systemctl status restic-backups-cube.timer
● restic-backups-cube.timer
     Loaded: loaded (/etc/systemd/system/restic-backups-cube.timer; enabled; preset: ignored)
     Active: active (waiting) since Sun 2026-08-30 20:25:16 EDT
    Trigger: Mon 2026-08-31 03:55:13 EDT

$ systemctl status restic-backups-cube.service
○ restic-backups-cube.service
     Loaded: loaded (/etc/systemd/system/restic-backups-cube.service; linked; preset: ignored)
     Active: inactive (dead)
```

`Loaded: ... linked` on the service (not `enabled`) is expected, not a
sign of anything wrong — it's `wantedBy`d only by the timer, the same
shape every other `services.restic.backups.*` unit has.

## Running a backup manually

```sh
sudo systemctl start restic-backups-cube.service
```

This runs the same unit the timer would — `backupPrepareCommand` (the
sqlite `.backup` staging step), the actual `restic backup`, then `restic
forget --prune` per `pruneOpts`. Watch it with `journalctl -u
restic-backups-cube -f` in a second terminal.

## Ad hoc restic commands

The module generates a wrapper (`createWrapper`, restic's own default) with
the same `RESTIC_REPOSITORY`/`RESTIC_PASSWORD_FILE`/etc. environment already
set:

```sh
sudo restic-cube snapshots
sudo restic-cube stats
sudo restic-cube check
```

`sudo` is required even though the wrapper itself is just a shell script —
`RESTIC_PASSWORD_FILE` resolves to `/run/secrets/restic-cube-password`
(confirmed by `nix eval
.#nixosConfigurations.nire-cube.config.sops.secrets.restic-cube-password.path`
— a path, not the secret value, safe to check this way), which is
root-owned mode `0400` by sops-nix's own default. Reading it as any other
user fails with a permission error, not a hang.

An interactive alternative to typing these by hand exists —
[rustic](rustic.md), on `elly`'s real `$PATH` on cube since the 2026-08-30
switch (confirmed `rustic 0.11.3` runs), but not yet actually pointed at
this repository — the NFS blocker above means there's nothing to browse
yet either way.

## Performing a restore — the actual bar for "done"

Per issue #87's own "done means": a green timer proves nothing. This is the
step that does:

```sh
sudo restic-cube snapshots                              # pick a snapshot ID, or use `latest`
sudo mkdir -p /root/restore-test
sudo restic-cube restore latest --target /root/restore-test --include /var/lib/forgejo
```

Then confirm it's actually usable, not just present — a file that restored
successfully but won't open proves nothing more than the timer did:

```sh
sudo ls -la /root/restore-test/var/lib/forgejo
sudo sqlite3 /root/restore-test/var/lib/forgejo/data/forgejo.db ".tables"
```

(The restored `forgejo.db` here is the live one restic excluded from
`paths` — it isn't in the backup. Restore
`/var/cache/restic-backups-cube/sqlite-staging/forgejo.db`'s backed-up
counterpart instead if checking the *staged* copy specifically; the `.db`
under `/var/lib/forgejo/data/` in a restored snapshot will be whatever was
already on disk when `paths` walked it, if anything — check
`sqliteStagingDir`'s own backed-up path first.)

Clean up afterward:

```sh
sudo rm -rf /root/restore-test
```

Write the outcome up here (or in `AGENTS.md`'s State section, per this
repo's usual place for a runtime-verified fact) once this has actually run
— that's what turns this module from configuration into a backup.

## Troubleshooting

- **`mount.nfs: access denied by server while mounting
  192.168.0.200:/restic-backup`** — the current, live blocker, not a
  hypothetical; see "The current blocker" above for the diagnosis and fix.
  This is what everything below used to guess at before it actually
  happened.
- **`sops-install-secrets: ... the key 'restic-cube-password' cannot be
  found` — a real, seen error, at `just build`/`just switch`, not just a
  hypothetical.** The key genuinely doesn't exist in whatever
  `secrets.yaml` is in the tree being built — check with `grep
  restic-cube-password flake/modules/nire/system/secrets/secrets.yaml`
  (safe: only the ciphertext key name is being checked, no decrypt
  involved). If it's missing from the checkout you're building from but you
  believe it's been set, check for a *different* checkout with the value
  already in it before assuming it needs generating from scratch — this bit
  once already (see "Switch cube" above for the two-checkout trap it came
  from) and is now fixed on `experimental`, so it should only recur if a
  future secret hits the same gap.
- **`unable to open repository at ...: unable to open config file` at
  runtime, after a successful build/switch** — the password file exists
  (the build wouldn't have succeeded otherwise) but is empty, or the NFS
  mount isn't actually up (`sudo cat /run/secrets/restic-cube-password |
  wc -c` should be non-zero; don't `cat` it bare per secrets-hygiene;
  `mount | grep restic-backup` for the mount).
- **The automount does *not* hang on the NFS failure above — it fails fast
  and loud**, correcting what this section used to guess: the journal shows
  the automount request and the `access denied by server` failure landing
  in the same second. If a *different* NFS problem ever does look like a
  hang instead (the QNAP host itself down, not just an ACL rejecting the
  client), `systemctl status mnt-restic\x2dbackup.automount` and plain
  reachability (`ping 192.168.0.200`) are still the right first checks.
- **A snapshot exists but a file inside looks unreadable/corrupt** — check
  whether it's one of the three excluded live sqlite dbs by mistake (see
  the restore section's parenthetical) before assuming the backup itself is
  bad.

## What's verified here

Checked live against cube and the QNAP, 2026-08-30, over ssh:

- **A real `just build`**, 2026-08-29 (synced over ssh — darwin can't
  cross-build `x86_64-linux`): clean full `system.build.toplevel`, `restic`/
  `restic-cube`/`rustic` all present in the resulting closure.
- **A real switch has happened.** `readlink /run/current-system` matches
  `nix eval --raw
  .#nixosConfigurations.nire-cube.config.system.build.toplevel` run against
  `~/projects/nix/nixos-configs`'s current commit, byte-for-byte.
- **`rustic` and `restic-cube` are both real, working binaries on cube's
  `$PATH`** — `which rustic` resolves under
  `/etc/profiles/per-user/elly/bin/`, and `rustic --version` prints
  `rustic 0.11.3`.
- **`restic-backups-cube.timer` is active and correctly scheduled** —
  `systemctl status` shows `active (waiting)`, next trigger the following
  03:55 (03:30 plus its `RandomizedDelaySec`).
- **The automount unit exists and actually attempted a mount** — triggered
  by `ls /mnt/restic-backup`, logged in the journal, and it failed with
  `access denied by server`. This is real, live evidence about the QNAP's
  export permissions, not a guess.
- **QNAP reachability, partially**: pings, and its admin web ports (443,
  8080) answer — the device is up and its NFS *server process* is running
  (it responded with an explicit rejection, not a timeout). SSH does not
  work, checked from both the LAN IP and the tailnet device name (`ts-hive`)
  — see "The current blocker" above.

**Not verified**: anything past the NFS mount succeeding — no backup has
run, no snapshot exists, no restore has been attempted, and the QNAP
snapshot schedule (setup step 2) is unconfirmed. This section gets filled
in further the first time each of those does.

## See also

- [backup](../categories/backup.md) — the module, the local-path-vs-SFTP
  reasoning, and what it evaluates to.
- [rustic](rustic.md) — a TUI that can browse and restore from this
  repository interactively, installed but not yet run against it.
- [Pending setup](pending-setup.md) — item 4, the tracking entry this
  runbook is the procedure for.
- [open-threads.md](../open-threads.md) — issue #87, the "Left open by the
  cube service stack" section.
- `claude cave/plans/2026-08-27-1816-cube-qnap-backup-plan.md` — the
  original plan, including the storage-NFS.nix correction.

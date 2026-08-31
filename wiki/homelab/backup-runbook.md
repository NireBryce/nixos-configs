# Backup runbook — restic on `nire-cube`

Operating [backup](../categories/backup.md) — the restic category that backs
up Forgejo/Grafana/golink's state and `/persist` to the QNAP NAS. That page
covers *why* it's shaped this way; this page is *what to actually type*, on
`nire-cube`, to finish setting it up, run it, check it, and restore from it.

**Status as of 2026-08-29: a real `just build` succeeds on cube.** Two
attempts, synced over ssh since darwin can't cross-build `x86_64-linux`: the
first failed at step 1 below — `sops-install-secrets` couldn't find
`restic-cube-password` in the `secrets.yaml` that attempt had, which turned
out to be a **build-time** failure (sops-nix validates its manifest as part
of `system.build.toplevel`), not just a runtime one. It turned out the
password *had* already been set, in a separate checkout on cube
(`~/projects/nix/nixos-configs`) the first attempt hadn't checked — merging
that checkout's `secrets.yaml` in and rebuilding gave a clean full toplevel,
`restic`/`restic-cube`/`rustic` all present. So: step 1's password exists,
just needs committing from wherever it actually lives — see that step below
for the current state, not the original "nothing is set yet" framing. Still
true: nothing has switched, the QNAP still hasn't been contacted, and no
command past step 1 has executed. Treat every other command here the way
[forgejo.md](forgejo.md) treats its untested ones — plausible from the
source, not proven. Update this page's own "What's verified here" section
the first time each later step actually runs.

## Before any of this works: two setup steps, once each

Both are also tracked in [Pending setup](pending-setup.md) item 4; this is
the actual procedure, not just the tracking entry.

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

Everything above can happen before or after this step, but nothing backs up
until it has:

```sh
cd ~/nixos-configs && git pull && just switch
```

Needs a password on cube (`sudo`), so this is a human step — an agent
session can build but not activate, per `AGENTS.md`'s Commands section.

## Checking status

```sh
systemctl status restic-backups-cube.service
systemctl list-timers restic-backups-cube.timer
journalctl -u restic-backups-cube -e
```

The timer fires daily at 03:30 plus up to a 30-minute random delay
(`timerConfig` in `restic.nix`) — `list-timers` shows the next scheduled run
without waiting for it.

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
[rustic](rustic.md), installed 2026-08-28 but not yet switched or run
against this repository, since it reads the same format.

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

- **`sops-install-secrets: ... the key 'restic-cube-password' cannot be
  found` — a real, seen error, at `just build`/`just switch`, not just a
  hypothetical.** The key genuinely doesn't exist in whatever
  `secrets.yaml` is in the tree being built — check with `grep
  restic-cube-password flake/modules/nire/system/secrets/secrets.yaml`
  (safe: only the ciphertext key name is being checked, no decrypt
  involved). If it's missing from the checkout you're building from but you
  believe it's been set, check for a *different* checkout with the value
  already in it before assuming it needs generating from scratch — this bit
  once already, see the module's own header. Setup step 1 above is where a
  missing key gets fixed for real.
- **`unable to open repository at ...: unable to open config file` at
  runtime, after a successful build/switch** — the password file exists
  (the build wouldn't have succeeded otherwise) but is empty, or the NFS
  mount isn't actually up (`sudo cat /run/secrets/restic-cube-password |
  wc -c` should be non-zero; don't `cat` it bare per secrets-hygiene;
  `mount | grep restic-backup` for the mount).
- **The service seems to hang at start** — `RequiresMountsFor` should
  trigger the automount, but if the QNAP itself is unreachable
  (`restic-backup`'s host, `192.168.0.200`, down or an export ACL problem),
  the automount attempt can hang rather than fail fast. Check
  `systemctl status mnt-restic\x2dbackup.automount` and plain reachability
  (`ping 192.168.0.200`) before assuming restic is the problem.
- **A snapshot exists but a file inside looks unreadable/corrupt** — check
  whether it's one of the three excluded live sqlite dbs by mistake (see
  the restore section's parenthetical) before assuming the backup itself is
  bad.

## What's verified here

**A real `just build` on cube, 2026-08-29** (synced over ssh, with
`~/projects/nix/nixos-configs`'s `secrets.yaml` merged in — see the status
note at the top): clean full `system.build.toplevel`, `restic`/
`restic-cube`/`rustic` all present in the resulting closure, `rustic
--version` run directly on cube and printing `rustic 0.11.3`.

**Not verified**: `just switch` (nobody has activated this generation), the
QNAP itself being reachable (the automount has never actually triggered
against the real NAS), and every command from "Checking status" onward —
none of them have executed. This section gets filled in further the first
time each of those does.

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

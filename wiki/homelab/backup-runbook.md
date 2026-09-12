# Backup runbook — restic on `nire-cube`

_Last modified: 2026-09-11_

Commands for operating [backup](../categories/backup.md) — the restic
category backing up Forgejo/Grafana/golink's state and `/persist` to the
QNAP NAS over SFTP. That page covers the design and its history (including
the sqlite consistency bug found and fixed 2026-09-06); this page is only
what to actually type. Confirmed fully working end to end 2026-09-06: a
real restore recovered a real, openable Forgejo database — see that
page's "The sqlite consistency bug" for the account.

All commands below run on `nire-cube` itself, with `sudo` — `restic-cube`
is a wrapper the module generates with `RESTIC_REPOSITORY`,
`RESTIC_PASSWORD_FILE`, and the SFTP identity already baked in, and those
resolve to root-owned `0400` files, so plain `restic` won't work
unprivileged.

> **Condensed version:**
> [backup-runbook-for-agents.md](backup-runbook-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [Checking status](#checking-status)
- [Creating a snapshot](#creating-a-snapshot)
- [Listing and inspecting snapshots](#listing-and-inspecting-snapshots)
- [Restoring a snapshot](#restoring-a-snapshot)
- [Deleting a snapshot](#deleting-a-snapshot)
- [Rotating the secrets](#rotating-the-secrets)
- [Troubleshooting](#troubleshooting)
- [See also](#see-also)

## Checking status

```sh
systemctl status restic-backups-cube.service
systemctl list-timers restic-backups-cube.timer
journalctl -u restic-backups-cube -e
```

`Loaded: ... linked` (not `enabled`) on the service is expected — it's
`wantedBy`d only by the timer, same as every other
`services.restic.backups.*` unit.

## Creating a snapshot

The timer fires daily at 03:30 plus up to a 30-minute random delay
(`timerConfig` in `restic.nix`) and runs the full cycle:
`backupPrepareCommand` (stages consistent sqlite copies of
Forgejo/Grafana/golink's databases), `restic backup`, `restic unlock`,
then `restic forget --prune` per `pruneOpts` (7 daily / 4 weekly / 6
monthly).

To run it on demand instead of waiting:

```sh
sudo systemctl start restic-backups-cube.service
journalctl -u restic-backups-cube -f     # in a second terminal, to watch it
```

`backupPrepareCommand` also logs its own run to a file that survives
across activations (`prepare.log`, unlike `/run/restic-backups-cube/`'s
ephemeral `RuntimeDirectory`) — useful for confirming the sqlite staging
step actually produced real files without waiting for the next restore:

```sh
sudo cat /var/cache/restic-backups-cube/prepare.log
```

## Listing and inspecting snapshots

```sh
sudo restic-cube snapshots
sudo restic-cube ls --recursive <snapshotID> [path]   # or 'latest'
sudo restic-cube stats
sudo restic-cube check
```

`ls` without `--recursive` only shows a directory's own tree entry, not
what's inside it — pass `--recursive` (with a path argument) whenever you
actually want to know if a directory's contents made it into the
snapshot, not just that the directory exists.

An interactive alternative exists — [rustic](rustic.md), on `elly`'s
`$PATH` on cube — but its env vars are `RUSTIC_*`, not `RESTIC_*`, and
it's unconfirmed whether it accepts the same `-o sftp.command=` shape
restic does.

## Restoring a snapshot

```sh
sudo mkdir -p /root/restore-test
sudo restic-cube restore latest --target /root/restore-test \
    --include /var/lib/forgejo \
    --include /var/lib/restic-backups-cube-sqlite-staging
```

`--include` the staging path explicitly if you want Forgejo/Grafana/
golink's actual database — the live `.db` files under `/var/lib/forgejo`
etc. are excluded from every backup on purpose (a live sqlite file can be
mid-write when restic reads it); the consistent, restorable copy lives
under `/var/lib/restic-backups-cube-sqlite-staging` instead.

Confirm it's actually usable, not just present:

```sh
sudo sqlite3 /root/restore-test/var/lib/restic-backups-cube-sqlite-staging/forgejo.db ".tables"
sudo rm -rf /root/restore-test   # clean up after
```

A real table listing (`repository`, `user`, `issue`, ...) is the actual
bar for "the backup works" — a green timer or a present-but-unopened file
proves neither.

## Deleting a snapshot

The timer already runs `forget --prune` automatically per `pruneOpts`
(above). To remove a specific snapshot by hand:

```sh
sudo restic-cube forget <snapshotID> --prune
```

`forget` alone marks a snapshot for removal without reclaiming space;
`--prune` does both in one step. If a previous operation was interrupted
and the repository reports itself locked:

```sh
sudo restic-cube unlock
```

## Rotating the secrets

Both live in `flake/modules/nire/system/secrets/secrets.yaml`, declared
in `restic.nix`. **Losing `restic-cube-password` loses the backups** —
restic has no recovery path for a forgotten repository password; keep a
copy somewhere that isn't cube and isn't this repo. Losing
`restic-cube-ssh-key` is recoverable (generate a new one, re-authorize it
on the QNAP) but breaks backups until that's done.

```sh
# Repository password
nix shell nixpkgs#sops nixpkgs#age --command \
    sops set flake/modules/nire/system/secrets/secrets.yaml \
    '["restic-cube-password"]' \
    "\"$(openssl rand -base64 32)\""

# SSH private key -- generate a new ed25519 keypair on cube first, append
# its public half to nire@ts-hive's authorized_keys, then:
ssh nire-cube.local 'cat ~/.ssh/<new-key>' \
    | jq -Rs . \
    | xargs -0 -I{} nix shell nixpkgs#sops nixpkgs#age \
        --command sops set \
        flake/modules/nire/system/secrets/secrets.yaml \
        '["restic-cube-ssh-key"]' {}
```

`jq -Rs .` JSON-encodes the multi-line key for `sops set`'s scalar
argument. Both values are generated/read inline, never a literal in the
command text — see `.agents/skills/secrets-hygiene/SKILL.md` if running
either from an agent session. Commit `secrets.yaml` after (safe, it's
ciphertext, committed encrypted on purpose — `AGENTS.md`, Safety
section), then `just switch` on cube to pick it up.

## Troubleshooting

- **`sops-install-secrets: ... the key 'restic-cube-ssh-key' cannot be
  found` (or `restic-cube-password`)** at build/switch time — the key
  genuinely doesn't exist in the `secrets.yaml` being built. Cube keeps
  two checkouts (`~/nixos-configs`, `~/projects/nix/nixos-configs`); check
  `git log -1` in both before assuming the secret needs regenerating —
  one may just be stale.
- **`unable to open repository at ...: unable to open config file`** at
  runtime — the password file is empty, or the SSH connection is failing
  before restic opens the repo. Test in isolation:
  `sudo -u root ssh -i /run/secrets/restic-cube-ssh-key nire@ts-hive echo ok`.
- **`Permission denied (publickey,password,keyboard-interactive)`** — the
  key isn't authorized on the QNAP side, or `IdentitiesOnly=yes` is
  masking a working key with a broken default one. Confirm the public
  half is in `nire@ts-hive`'s `~/.ssh/authorized_keys` and that
  `/run/secrets/restic-cube-ssh-key` actually decrypted.
- **Host key verification failed** — the QNAP's SSH host key changed
  (reinstall, firmware reset) and no longer matches
  `programs.ssh.knownHosts."ts-hive"` in `restic.nix`. Re-run
  `ssh-keyscan -t ed25519 ts-hive`, confirm the change is expected, and
  update the pinned key — don't just delete the pin.
- **A restored file looks empty or unopenable** — check whether it's one
  of the three excluded live sqlite dbs (`/var/lib/forgejo/data/forgejo.db`
  etc.) rather than the staged copy under
  `/var/lib/restic-backups-cube-sqlite-staging` — see "Restoring a
  snapshot" above.

## See also

- [backup](../categories/backup.md) — the module's design, and the full
  incident history (the SFTP/NFS switch, the repository-path migration,
  the sqlite consistency bug).
- [backup-history.md](../categories/backup-history.md) — the original
  plan and every one-time setup snag, in full.
- [rustic](rustic.md) — an interactive TUI alternative to the commands
  above.
- [Pending setup](pending-setup.md) — item 4, now closed; this page is
  the procedure it points to.
- [open-threads.md](../open-threads.md) — issue #87.

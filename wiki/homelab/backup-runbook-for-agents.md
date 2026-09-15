# Backup runbook, for agents

_Last modified: 2026-09-11_

Condensed from [backup-runbook.md](backup-runbook.md); design is
[../categories/backup-for-agents.md](../categories/backup-for-agents.md).

All of this runs **on `nire-cube`, with `sudo`**. `restic-cube` is a
module-generated wrapper with repository, password file and SFTP identity
baked in; those files are root-owned `0400`, so plain `restic` fails.

## Status

```sh
systemctl status restic-backups-cube.service
systemctl list-timers restic-backups-cube.timer
journalctl -u restic-backups-cube -e
sudo cat /var/cache/restic-backups-cube/prepare.log   # sqlite staging log
```

`Loaded: ... linked` (not `enabled`) is **expected** — `wantedBy` the timer
only.

## Run and inspect

Timer: daily 03:30 + up to 30min delay. Cycle: `backupPrepareCommand` →
`backup` → `unlock` → `forget --prune` (7 daily / 4 weekly / 6 monthly).

```sh
sudo systemctl start restic-backups-cube.service
sudo restic-cube snapshots
sudo restic-cube ls --recursive <snapshotID|latest> <path>
sudo restic-cube stats ; sudo restic-cube check
sudo restic-cube forget <snapshotID> --prune   # `forget` alone reclaims nothing
sudo restic-cube unlock                        # after an interrupted run
```

**`ls` without `--recursive` shows only the directory's own tree entry**, not
its contents — pass it plus a path whenever the question is whether something
made it in.

## Restore

```sh
sudo restic-cube restore latest --target /root/restore-test \
    --include /var/lib/forgejo \
    --include /var/lib/restic-backups-cube-sqlite-staging
sudo sqlite3 /root/restore-test/var/lib/restic-backups-cube-sqlite-staging/forgejo.db ".tables"
```

**The live `.db` files are excluded from every backup on purpose** — the
restorable copy is under `.../sqlite-staging`. `--include` it explicitly or
you restore no database at all.

**A real table listing is the bar for "the backup works."** A green timer
proves nothing.

## Rotating the secrets

Both in `secrets.yaml`, declared in `restic.nix`. **Losing
`restic-cube-password` loses the backups** — no recovery path; keep a copy
off cube and outside this repo. `restic-cube-ssh-key` is recoverable.

Generate values inline, never as a literal in the command (skill
`secrets-hygiene`); `jq -Rs .` JSON-encodes a multi-line key for `sops set`.
Commands: [backup-runbook.md](backup-runbook.md#rotating-the-secrets). Commit
`secrets.yaml` after, then `just switch` on cube.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `the key '...' cannot be found` at switch | **cube has two checkouts** (`~/nixos-configs`, `~/projects/nix/nixos-configs`). `git log -1` in both before regenerating anything — one may just be stale. |
| `unable to open config file` | empty password file, or SSH failing before restic opens the repo. Test: `sudo -u root ssh -i /run/secrets/restic-cube-ssh-key nire@ts-hive echo ok` |
| `Permission denied (publickey,...)` | key not authorized on the QNAP, or `IdentitiesOnly=yes` masking it |
| `Host key verification failed` | QNAP host key changed. `ssh-keyscan -t ed25519 ts-hive`, confirm expected, **update** `programs.ssh.knownHosts."ts-hive"` — don't delete the pin |
| restored file unopenable | you restored an excluded live db, not the staged copy |

## See also

[backup-runbook.md](backup-runbook.md) · [rustic.md](rustic.md) (TUI
alternative; its env vars are `RUSTIC_*`, not `RESTIC_*`)

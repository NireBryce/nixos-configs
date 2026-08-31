# Backup runbook — restic on `nire-cube`

Operating [backup](../categories/backup.md) — the restic category that backs
up Forgejo/Grafana/golink's state and `/persist` to the QNAP NAS. That page
covers *why* it's shaped this way; this page is *what to actually type*, on
`nire-cube`, to finish setting it up, run it, check it, and restore from it.

**Status as of 2026-08-31: SFTP, not NFS.** This module shipped with a
local-path repository on an NFS mount; a real switch on cube hit
`mount.nfs: access denied by server` (the QNAP's export permissions for the
dedicated `restic-backup` share never included cube). Chasing that down led
to enabling SSH on the QNAP and switching to SFTP instead — real
per-connection key auth rather than an IP allowlist, and issue #87's
original plan besides. **Nothing has been built or switched with the SFTP
repository yet** — see "What's verified here" for exactly how far this got
(a real build on cube, confirming everything works except the two secrets
this session can't set) before this page trusts anything past that.

The NFS-era troubleshooting this page used to carry is gone — it's history
now, in the module's own header (`restic.nix`), not duplicated here.

## Before any of this works: four setup steps

Tracked in [Pending setup](pending-setup.md) item 4. Step 3 (SSH's own
exposure) is done; 1, 2, and 4 aren't.

### 1. Set the two sops secrets

Neither has a value in this tree — both need real decrypt access to
`secrets.yaml` (one of the age keys enrolled in `.sops.yaml`: durandal,
lysithea, tenacity, or cube's own host key), which the session that wrote
the SFTP switch didn't have.

**The repository password** (`restic-cube-password`) — generate fresh, or
skip if it's already set elsewhere (check first: `grep
restic-cube-password flake/modules/nire/system/secrets/secrets.yaml`, safe,
only the ciphertext key name):

```sh
nix shell nixpkgs#sops nixpkgs#age --command \
    sops set flake/modules/nire/system/secrets/secrets.yaml \
    '["restic-cube-password"]' \
    "\"$(openssl rand -base64 32)\""
```

**The SSH private key** (`restic-cube-ssh-key`) — a dedicated ed25519 key
was generated on cube specifically for this
(`~/.ssh/restic-cube-backup`, no passphrase — it has to work unattended)
and its public half is already installed in `nire@ts-hive`'s
`authorized_keys` on the QNAP, confirmed working by hand. What's left is
getting the *private* half into `secrets.yaml`:

```sh
ssh nire-cube.local 'cat ~/.ssh/restic-cube-backup' \
    | jq -Rs . \
    | xargs -0 -I{} nix shell nixpkgs#sops nixpkgs#age \
        --command sops set \
        flake/modules/nire/system/secrets/secrets.yaml \
        '["restic-cube-ssh-key"]' {}
```

`jq -Rs .` JSON-encodes the multi-line key (escaping newlines) into the
scalar `sops set` expects as a value. Once this has run, `ssh nire-cube.local
'rm ~/.ssh/restic-cube-backup*'` — that file's only job was carrying the key
into secrets.yaml.

Both values are generated/read inline, never a literal in the command text
or anything that echoes back — see `.claude/skills/secrets-hygiene/SKILL.md`
if running either from an agent session. Commit `secrets.yaml` after —
safe, it's ciphertext, and this repo commits it encrypted on purpose
(`AGENTS.md`, Safety section).

**Losing the repository password loses the backups** — restic has no
recovery path for a forgotten one; write it down somewhere that isn't cube
and isn't this repo. Losing the SSH key is recoverable (generate a new one,
re-authorize it on the QNAP) but breaks the backup until that's done.

### 2. Configure a QNAP-side snapshot schedule on the backup share

The anti-deletion mitigation: `nire` can write and prune within
`~/restic-cube` over SFTP but shouldn't be able to erase the NAS's own
snapshots of it. **Not verified against the QNAP's actual menu layout** —
treat this as a starting point, not a copy-paste procedure:

1. QNAP admin console → Control Panel → Storage & Snapshots (or the
   snapshot manager for the volume `restic-backup` lives on).
2. Find or create a scheduled snapshot job for the `restic-backup` share.
3. A daily schedule with a few days/weeks of retention is enough to recover
   from an accidental or malicious `restic forget --prune`; it doesn't need
   to match restic's own retention.

If the QNAP's snapshot granularity is coarser than a single share, the
remaining fallback from issue #87's list is `restic-rest-server` in
append-only mode, if the QNAP has Container Station.

### 3. Mitigating SSH's own exposure — done, 2026-08-31

QuTS hero has no toggle to force key-only SSH auth, so enabling it at all on
the QNAP means password auth stays reachable too — mitigated at the network
level instead:

- **Port 22 is LAN-blocked, tailnet-only.** Confirmed live, both directions:
  `192.168.0.200:22` times out from both lysithea and cube (neither can
  reach it over the LAN anymore); `ts-hive`'s tailnet address
  (`100.78.140.91:22`) still accepts a connection from cube.
- **No further Tailscale ACL restriction** — every tailnet device can still
  reach it, a deliberate choice, not an oversight: the existing tailnet
  policy already grants `autogroup:members` full reachability to every
  member device (see the earlier discussion this runbook doesn't
  duplicate), and narrowing that specifically for `ts-hive` would mean
  restructuring a shared policy for marginal benefit once the LAN block
  above is in place.
- **QNAP brute-force protection (Network Access Protection) is on** — taken
  on confirmation, not independently checked (no `sudo` on the QNAP from
  here to inspect it directly).

### 4. Switch cube

Nothing above requires this to already be done, but nothing backs up until
it has:

```sh
cd ~/projects/nix/nixos-configs && git pull && just switch
```

**Checkout trap**: cube has *two* clones of this repo. `~/nixos-configs` is
stale (behind, last checked 2026-08-30); `~/projects/nix/nixos-configs` is
the one that's actually current — this bit once already (see `restic.nix`'s
own header for the fuller account) when a build was run from the wrong one
and it looked like a missing secret that wasn't actually missing anywhere.
Check which you're in before trusting its `git log`.

`sudo` on cube needs a password, so this is a human step — an agent session
can build but not activate (`AGENTS.md`, Commands section).

## Checking status

```sh
systemctl status restic-backups-cube.service
systemctl list-timers restic-backups-cube.timer
journalctl -u restic-backups-cube -e
```

The timer fires daily at 03:30 plus up to a 30-minute random delay
(`timerConfig` in `restic.nix`) — `list-timers` shows the next scheduled run
without waiting for it. `Loaded: ... linked` (not `enabled`) on the service
itself is expected, not a sign of anything wrong — it's `wantedBy`d only by
the timer, the same shape every other `services.restic.backups.*` unit has.

## Running a backup manually

```sh
sudo systemctl start restic-backups-cube.service
```

This runs the same unit the timer would — `backupPrepareCommand` (the
sqlite `.backup` staging step), the actual `restic backup` over SFTP, then
`restic forget --prune` per `pruneOpts`. Watch it with `journalctl -u
restic-backups-cube -f` in a second terminal.

## Ad hoc restic commands

The module generates a wrapper (`createWrapper`, restic's own default) with
the same environment the systemd unit gets — `RESTIC_REPOSITORY`,
`RESTIC_PASSWORD_FILE`, and the `-o sftp.command=...` flag pointing at the
dedicated key, all baked in:

```sh
sudo restic-cube snapshots
sudo restic-cube stats
sudo restic-cube check
```

`sudo` is required even though the wrapper itself is just a shell script —
`RESTIC_PASSWORD_FILE` resolves to `/run/secrets/restic-cube-password`
(confirmed by `nix eval
.#nixosConfigurations.nire-cube.config.sops.secrets.restic-cube-password.path`
— a path, not the secret value, safe to check this way), root-owned mode
`0400` by sops-nix's own default. The SSH private key
(`/run/secrets/restic-cube-ssh-key`) is the same shape. Reading either as
any other user fails with a permission error, not a hang.

An interactive alternative to typing these by hand exists —
[rustic](rustic.md), on `elly`'s real `$PATH` on cube since the 2026-08-30
switch (confirmed `rustic 0.11.3` runs) — but its own env vars are
`RUSTIC_*`, not `RESTIC_*`, and it's unconfirmed whether it accepts the same
`-o sftp.command=` shape restic does; see that page.

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

- **`sops-install-secrets: ... the key 'restic-cube-ssh-key' cannot be
  found` (or `restic-cube-password`)** — a real, seen error at
  `just build`/`just switch`, build-time (sops-nix validates its manifest
  as part of `system.build.toplevel`), not just runtime. The key genuinely
  doesn't exist in whatever `secrets.yaml` is in the tree being built — see
  setup step 1 above. If you believe a value was already set somewhere,
  check for a *different* checkout with it before assuming it needs
  regenerating — cube has two clones (see "Switch cube" above), and this
  exact confusion happened once already with the password.
- **`unable to open repository at ...: unable to open config file` at
  runtime, after a successful build/switch** — the password file is empty,
  or the SSH connection itself is failing before restic even gets to open
  the repo. Test the connection in isolation:
  `sudo -u root ssh -i /run/secrets/restic-cube-ssh-key nire@ts-hive
  echo ok` (as root, since that's who owns the key file).
- **`Permission denied (publickey,password,keyboard-interactive)`** — the
  key isn't authorized on the QNAP side, or `IdentitiesOnly=yes` is masking
  a working key with a broken default one. Confirm the public half is still
  in `nire@ts-hive`'s `~/.ssh/authorized_keys` (it was appended by hand,
  2026-08-31, not managed by anything that could have reverted it) and that
  `/run/secrets/restic-cube-ssh-key` actually decrypted (see the sops error
  above if not).
- **Host key verification failed** — the QNAP's SSH host key changed
  (reinstall, firmware reset) and no longer matches
  `programs.ssh.knownHosts."ts-hive"` in `restic.nix`. Re-run
  `ssh-keyscan -t ed25519 ts-hive` against the real host, confirm the change
  is expected, and update the pinned key in the module — don't just delete
  the pin, that's what it exists to catch.
- **A snapshot exists but a file inside looks unreadable/corrupt** — check
  whether it's one of the three excluded live sqlite dbs by mistake (see
  the restore section's parenthetical) before assuming the backup itself is
  bad.

## What's verified here

Checked live against cube and the QNAP, 2026-08-31, over ssh (bounced
through cube — this darwin machine has no Tailscale of its own, so `ts-hive`
is only reachable via `ssh nire-cube.local 'ssh ... ts-hive ...'`):

- **SSH now works on the QNAP.** `ssh nire@ts-hive` (as `nire`, not the
  default `elly`) authenticates with cube's existing personal key with no
  password prompt — a real change from before, when the port refused the
  connection outright on both the LAN and the tailnet.
- **The dedicated backup key works too.** `ssh -i
  ~/.ssh/restic-cube-backup nire@ts-hive` authenticates cleanly, confirming
  the public half landed correctly in `authorized_keys`.
- **A real `just build` on cube with the SFTP module**: fails, but at
  exactly the predicted point — `sops-install-secrets` can't find
  `restic-cube-ssh-key`, since this session never had decrypt access to set
  it. 21 other derivations built clean around that failure, including a
  full, separate `home-manager-generation` build (`rustic` present and
  confirmed running, `rustic --version` → `rustic 0.11.3`) — nothing else
  about the SFTP switch is broken.
- **The generated `sftp.command` is well-formed** — read back from the
  evaluated `systemd.services."restic-backups-cube".preStart`, not just the
  Nix source: `restic -o sftp.command='.../ssh -i /run/secrets/restic-cube-ssh-key
  -o IdentitiesOnly=yes nire@ts-hive -s sftp' cat config > /dev/null ||
  ... init`, matching nixpkgs' own documented shape for this option
  exactly.
- **durandal/tenacity/lysithea toplevels are byte-identical** before and
  after the SFTP switch, confirmed by `git stash`-isolating just the
  `restic.nix` change, not inferred from category scoping alone.

- **SSH's LAN exposure is closed, tailnet-only now** — `192.168.0.200:22`
  times out from both lysithea and cube; `ts-hive`'s tailnet address still
  accepts a connection. See setup step 3 above for the full account,
  including what's taken on confirmation rather than independently checked.

**Not verified**: anything past the SSH connection and the build — no
backup has run, no snapshot exists, no restore has been attempted, and the
QNAP snapshot schedule (setup step 2) is unconfirmed. This section gets
filled in further the first time each of those does.

## See also

- [backup](../categories/backup.md) — the module, the NFS-to-SFTP switch
  and why, and what it evaluates to.
- [rustic](rustic.md) — a TUI that can browse and restore from this
  repository interactively, installed but not yet run against it.
- [Pending setup](pending-setup.md) — item 4, the tracking entry this
  runbook is the procedure for.
- [open-threads.md](../open-threads.md) — issue #87, the "Left open by the
  cube service stack" section.
- `claude cave/plans/2026-08-27-1816-cube-qnap-backup-plan.md` — the
  original plan, including the storage-NFS.nix correction (from the era
  before this module moved off NFS entirely).

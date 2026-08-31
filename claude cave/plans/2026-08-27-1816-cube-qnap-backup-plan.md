# Plan: back up cube's service state to the QNAP NAS

**Written 2026-08-27 18:16 EDT. Status as of 2026-08-28: implemented in Nix,
not yet switched.** This plan was against issue
[#87](https://github.com/NireBryce/nixos-configs/issues/87) (open, filed
2026-08-24, "not decided") and
[wiki/homelab/pending-setup.md](../../wiki/homelab/pending-setup.md) item 4;
it doesn't supersede either, and #87 stays open until a real restore has been
performed per its own "done means". The module this plan describes now
exists as [`nire/homelab/backup/`](../../flake/modules/nire/homelab/backup/)
— see [wiki/categories/backup.md](../../wiki/categories/backup.md) for
current status, and don't trust this file's own "Steps"/"Open questions"
sections below as still-open once that page says otherwise.

**Correction, found while implementing (2026-08-28):** "storage-NFS.nix
already exists in the tree... It's dangling — not imported by any host" a
few paragraphs down is **wrong**. `nire/system/storage/` has no
`dirsAsCategory.nix` of its own, so that module is collected straight into
the shared `system` aggregate, which every Linux host already imports — the
QNAP mount was live on durandal, tenacity, and cube before this plan was
even written, confirmed by `nix eval .#nixosConfigurations.<host>.config.
fileSystems` listing `/mnt/qnap-erin` on all three. Left the paragraph below
as originally written rather than silently fixed, per this repo's "a bug
recorded in a comment stays in the file" convention — the module itself
(`restic.nix`) carries the same correction in its own header, which is the
copy to trust.

**Mount point renamed, same day (2026-08-28), unrelated to the correction
above:** `/mnt/qnap-erin` (device `192.168.0.200:/erin-pub`), named
throughout the rest of this file, is now `/mnt/restic-backup` (device
`192.168.0.200:/restic-backup`) — a share dedicated to this backup rather
than shared with other QNAP uses. `storage-NFS.nix` and `restic.nix` both
carry the current path; this file's own later mentions of `qnap-erin`/
`erin-pub` are left as written, for the same "don't silently rewrite"
reason as the correction above.

Written from a read of the repo, not from any live session on cube — nothing
at the time of writing had touched the real machine or the real QNAP; see the
category page for what's since been checked by evaluation (still no real
switch, no real QNAP contact).

## What's at risk (from #87, re-confirmed by grep 2026-08-27)

Cube has a **plain persistent root, no impermanence** — "survives reboot" is
the only durability property any of this has, and nothing in `flake/`
configures a backup tool.

| Path | Contents | Recreatable? |
|---|---|---|
| `/var/lib/forgejo` | repos, sqlite db, self-generated secrets | no |
| `/var/lib/grafana` | sqlite db — UI-created dashboards live only here | no (provisioned ones come from the store) |
| `/var/lib/private/golink` | links db + tsnet node key | no (key loss re-registers a new device) |
| `/persist/secrets/`, `/persist/passwords/` | hand-created, nothing in the repo recreates them | no |

Deliberately excluded: Prometheus's TSDB (`monitoring` category) — regenerable
metrics history, biggest path, least valuable, per #87's own open question 4.

## Recommended shape

**restic, with the repository as a local path on the QNAP NFS export, not
SFTP.** This differs from #87's original sketch (restic over SFTP) — the
reasoning:

- [`nire/system/storage/storage-NFS.nix`](../../flake/modules/nire/system/storage/storage-NFS.nix)
  already exists in the tree: an NFS automount to `192.168.0.200:/erin-pub`
  (the QNAP, hostname "erin"). It's dangling — not imported by any host,
  cube included — but it means the mount is a one-line import away instead of
  new infrastructure.
- restic encrypts client-side regardless of backend, so a local-path repo on
  an NFS mount gets the same encryption-at-rest #87 wanted from SFTP, without
  needing SSH keys, a restricted backup user, or (if going further)
  `rest-server`/Container Station on the QNAP side.
- Trade-off, stated plainly: NFS export trust is IP-based, not keyed. Anyone
  on the LAN with that IP can mount `erin-pub`. This plan accepts that and
  compensates with QNAP-side snapshots (below) rather than switching to SFTP
  — flag this explicitly to Elly as the one point in this plan that's a
  judgment call, not a settled fact from the repo.

## Steps

1. **Size the paths first.** `du -sh /var/lib/forgejo /var/lib/grafana
   /var/lib/private/golink /persist` on cube, over ssh — hasn't been run
   (#87's own open question 5). Do this before committing to a retention
   policy.
2. **Import `storage` into `cube-configuration.nix`.** Mounts
   `/mnt/qnap-erin` via `x-systemd.automount`.
3. **Confirm the QNAP side is ready**: a share (or subfolder of `erin-pub`)
   for the restic repo, and — this is the part that needs Elly, not
   something checkable from the repo — a **native QNAP snapshot schedule on
   that share**. This is the anti-deletion mitigation for #87's open
   question 3 (push means cube can delete its own backups): cube can write
   and prune within the restic repo, but can't touch the NAS's own
   snapshots, so a compromised or wiped cube can't retroactively erase
   history. Cheapest rung of the ascending-effort list #87 already proposes
   for this problem.
4. **New `nire/backup/` category**, cube-only to start (same shape as
   `monitoring`, `git-forge`, etc. — see `new-homelab-service` skill),
   holding `services.restic.backups.cube`:
   - `repository = "/mnt/qnap-erin/restic-cube"` (local-path backend)
   - `paths` = the four rows in the table above
   - `passwordFile` from a new sops secret (`restic-cube-password`, same
     pattern as the existing `syncthing-*` secrets in
     `nire/system/secrets/secrets.yaml`)
   - `initialize = true`
   - `backupPrepareCommand` running `sqlite3 <db> ".backup <staging>"` for
     Forgejo's, Grafana's, and golink's db files before each run — backing
     up the staging copies, not the live db, to avoid capturing a torn write
     (#87's open question 1). `forgejo dump` as the belt-and-braces version
     for the forge specifically.
   - `timerConfig`: daily, `RandomizedDelaySec` set (matters more once other
     hosts might target the same NAS).
   - `pruneOpts`: not yet decided — depends on step 1's sizing.
5. **Repo password, kept outside cube too** (#87's open question 2): the
   sops secret above is necessary but not sufficient — if cube's disk is
   gone, the age key needed to decrypt that secret is gone with it. A copy
   needs to exist somewhere that isn't cube (password manager, printed) —
   this is a human step, not a Nix change, and belongs on
   `wiki/homelab/pending-setup.md` once step 4 lands, the same way Forgejo's
   admin bootstrap and golink's first links do.
6. **Restore drill.** Not done until one Forgejo repo is actually pulled back
   out of the restic repo and confirmed to open — per #87 and
   `pending-setup.md`'s own definition of done. Write this up wherever the
   rest of the fleet's runtime confirmations live (`CLAUDE.md`'s State
   section, going by precedent).

## Open questions for Elly specifically

- NFS-local-path vs SFTP: accept the IP-trust trade-off in exchange for not
  standing up SSH/rest-server on the QNAP, or is SFTP worth the extra QNAP
  setup for keyed auth? (See "trade-off" note above.)
- Does the QNAP support scheduled snapshots on a single share, or only at
  the volume level? Changes how narrowly step 3 can be scoped.
- Retention policy, once step 1's sizing is in.

## See also

- Issue [#87](https://github.com/NireBryce/nixos-configs/issues/87) — the
  tracking issue this plan is against.
- [wiki/homelab/pending-setup.md](../../wiki/homelab/pending-setup.md) item 4
  — the fleet-side "still needs a human" tracking; update once this plan
  starts landing.
- [wiki/open-threads.md](../../wiki/open-threads.md) — repo-side loose-end
  tracking, "Left open by the cube service stack" section.
- Skill `new-homelab-service` — the process this plan's step 4 follows.

# Maintenance schedule

_Last modified: 2026-09-16_

> **Condensed version:**
> [maintenance-schedule-for-agents.md](maintenance-schedule-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [What this is](#what-this-is)
- [Why this file is plaintext, not sops-encrypted](#why-this-file-is-plaintext-not-sops-encrypted)
- [Items](#items)
- [Adding a new item](#adding-a-new-item)
- [See also](#see-also)

## What this is

A checklist of this fleet's credentials, keys, and certificates that have
**an actual expiry, a recommended rotation cadence, or a "will silently
break later" property** — as opposed to `secrets.yaml`'s full inventory,
which is every secret regardless of whether it ever needs attention. Tended
by skill [`maintenance-schedule`](../.agents/skills/maintenance-schedule/SKILL.md).

Each item states what it actually is, what's known about its expiry (not
guessed — "unverified" is written down as such rather than invented), and
where the real rotation procedure lives if there is one. This page is the
index that says *something is due*; `backup-runbook.md` and similar own the
*how*.

## Why this file is plaintext, not sops-encrypted

Considered and rejected: sops-encrypting this file the way `secrets.yaml`
is. Nothing on this page is a secret *value* — key **names**, rotation
**dates**, and expiry **durations** aren't the credentials themselves, the
same reasoning `secrets-hygiene`'s skill applies to `secrets.yaml`'s own key
names (safe to `cat`/`git show`; only the `ENC[...]` payload is sensitive).
Encrypting a schedule that exists specifically to be checked on a cadence
would work against its own purpose — nobody re-derives a due date through
`sops -d` on a regular basis, and a wiki page has no age-key access control
to begin with.

**This judgment flips per-row, not for the whole file**, if a row ever needs
to hold an actual secret value (a real key material dump, not a name or a
date) — encrypt that value with sops the normal way and reference it from
here, don't wrap this file in ciphertext to protect one row.

## Items

### 1. `tailscale_key` — Tailscale auth key

- **What**: an auth key stored in `secrets.yaml`, undeclared and unused —
  see [`tailscale.nix`](../flake/modules/config-system/system/networking/tailscale.nix)'s
  header comment.
- **Expiry**: Tailscale auth keys expire at **90 days maximum** from
  creation. This one predates the flake-parts port (so it's already stale)
  and isn't wired to anything — no `sops.secrets.tailscale_key`, no
  `authKeyFile` — so its expiry currently has zero operational effect.
- **If this ever gets wired in**: mint a fresh key first (an expired one
  fails `tailscaled-autoconnect.service` on every boot rather than
  degrading gracefully), and either plan on re-minting every ≤90 days or
  generate a **reusable, non-expiring** key from the Tailscale admin
  console if unattended re-auth matters more than key hygiene.
- **Last checked**: 2026-09-07 (file inventory only — key not decrypted,
  per `secrets-hygiene`).

### 2. `tailscale_api_token`

- **What**: added 2026-09-07 (commit `63dcfe1b`) — a Tailscale API token,
  scoped to the tailnet's policy file, read narrowly by
  [`flake/scripts/tailscale-acl.py`](../flake/scripts/tailscale-acl.py) via
  `sops -d --extract`. Unlike `tailscale_key` above, this one is actually
  wired up and in active use (confirmed end-to-end against the real
  tailnet per that commit's message).
- **Expiry**: **unverified** — depends on how the token was minted (a
  classic Tailscale API access token defaults to 90 days; an OAuth client
  secret doesn't expire but the short-lived access tokens it issues do).
  This page doesn't assert which kind it is; check the [Tailscale admin
  console](https://login.tailscale.com/admin/settings/keys)'s API
  access/OAuth clients list to find out, and record it here once known.
- **Failure mode if it expires**: `tailscale-acl.py get`/`apply`/`vip-*`
  start failing auth — silent until someone next tries to touch the ACL or
  a `svc:` definition through the script rather than the admin console by
  hand.
- **Last checked**: 2026-09-07 (existence and usage confirmed from the
  landing commit and script header; expiry type not yet verified live).

### 3. Tailscale node key expiry (per-machine)

- **What**: separately from auth keys, each *node* Tailscale admits to the
  tailnet has its own key expiry (default 180 days unless "Disable key
  expiry" is set for that machine in the admin console). An expired node
  key drops the machine off the tailnet until `tailscale up` is re-run
  interactively.
- **Status**, read from `tailscale status --json` run on `nire-tenacity`
  (a live per-node read, equivalent to the admin console's machines list):
  - `nire-durandal` — expiry **disabled** (`KeyExpiry: null`). Fine as-is.
  - `nire-cube` — expiry **enabled**, expires **2027-02-18**. Not disabled
    despite being the one host running unattended headless homelab
    services (see below) — worth disabling in the admin console rather
    than relying on someone noticing before it lapses.
  - `nire-tenacity` (self) — expires 2027-02-18.
  - `homeassistant`, `go`, `ts-hive`, `samsung SM-S911U` — all expire
    2027-02-18 to 2027-02-27.
  - `nire-lysithea` — appears **twice** in the peer list, both offline,
    with two different expiry dates (2026-12-13 and 2027-02-27) — looks
    like a stale duplicate registration from a past reinstall. Worth
    pruning the older one from the admin console.
- **Why `nire-cube` matters most**: it runs unattended homelab services
  behind Tailscale (see [homelab/reaching-services.md](homelab/reaching-services.md));
  a silent node-key expiry there means every service behind it becomes
  unreachable with no config change to explain why.
- **Last checked**: 2026-09-07, via `tailscale status --json` on
  `nire-tenacity` (live device state, not a repo-file inference).

### 4. sops age recipients — derived from host SSH host keys

- **What**: `.sops.yaml`'s four `age1...` recipient lines
  (`flake/modules/config-system/system/secrets/.sops.yaml`) are each derived from
  that host's own `/etc/ssh/ssh_host_ed25519_key.pub` via `just age-key`
  (`flake/scripts/host-age-key.sh`) — not standalone `age-keygen` keypairs.
- **Expiry**: none in the usual sense — SSH host keys don't expire on a
  timer. They **do** change whenever a host's SSH host key is regenerated
  (a reinstall, a `sshd` host-key rotation), which silently orphans that
  host's entry in `.sops.yaml` until re-enrolled.
- **Action when it happens**: re-run `just age-key` for the affected host,
  update `.sops.yaml`, then `sops updatekeys secrets.yaml` — see
  [impermanence-and-secrets.md](impermanence-and-secrets.md)'s Secrets
  section.
- **Last checked**: 2026-09-07 (four recipients present, matching the four
  live hosts enrolled per `CLAUDE.md`'s Safety section — names, not values,
  read).

### 5. `restic-cube-ssh-key` / `restic-cube-password`

- **What**: backup credentials `nire-cube` uses to reach the QNAP over SSH
  and encrypt the restic repo.
- **Rotation history**: 2026-08-27 (`restic-cube-password`) and 2026-08-31
  (`restic-cube-ssh-key`) — see
  [homelab/pending-setup.md](homelab/pending-setup.md)'s backups section
  for the dated log.
- **Procedure**: [homelab/backup-runbook.md](homelab/backup-runbook.md)'s
  ["Rotating the secrets"](homelab/backup-runbook.md#rotating-the-secrets)
  section — the actual `sops set` commands live there, not duplicated here.
- **Cadence**: no fixed schedule; rotate on suspicion of compromise or QNAP
  re-image. Not time-boxed like the Tailscale items above.
- **Last checked**: 2026-08-31 (per the dated rotation log linked above).

### 6. QNAP SSH host key pin

- **What**: `nire-cube`'s pinned host key for the QNAP backup target.
- **Expiry**: none — this isn't a credential that expires, but it *breaks*
  the same way an expired one would (backup runs start failing) whenever
  the QNAP is re-imaged or its host key otherwise changes. Grouped here
  because the failure mode and the fix are maintenance-shaped even though
  nothing is actually expiring.
- **Procedure**: `backup-runbook.md`'s "Host key verification failed" entry
  — update the pin, don't delete it blind.
- **Last checked**: not tracked independently; only noticed when a backup
  run fails.

### 7. `forgejo-admin-password`

- **What**: the Forgejo instance's local admin account password.
- **Expiry**: none enforced by Forgejo. No rotation has happened since it
  was set.
- **Recommendation**: no fixed cadence exists yet for this repo; treat as
  due for a look whenever this page is reviewed (see the skill) rather than
  on its own timer, since it's a low-traffic single-admin instance behind
  Tailscale, not internet-facing.
- **Last checked**: not yet rotated since initial setup — see
  [homelab/forgejo.md](homelab/forgejo.md).

### 8. Grafana admin credentials

- **What**: a real admin password, **set by hand through the UI 2026-09-13**
  (by the user). Not stock any more. Lives only in cube's Grafana sqlite db at
  `/var/lib/grafana` — covered by restic, but not reproducible: nothing
  re-applies it, so it is a credential that exists in exactly one place.
- **Also, separately**: `grafana-admin-password` now exists in
  `secrets.yaml` and `grafana.nix` wires it to
  `settings.security.admin_password` via Grafana's `$__file{}` provider.
  **That governs first start only** — Grafana's `defaults.ini`: "can be
  changed before first start of grafana, or in profile settings". Its job is
  that a fresh or rebuilt instance never comes up on the published
  `admin`/`admin` again; it does **not** manage the password above.
- **Rotation**: none enforced. To rotate the live one, change it in the UI.
  To rotate what a rebuilt instance would get, `sops set` the secret.
  The two are independent, which is the cost of first-start-only semantics.
- **What would make them one thing**: a oneshot running `grafana-cli admin
  reset-admin-password` from the sops file per activation — the shape
  `forgejo-admin-bootstrap` uses for item 7. Deliberately not done: it
  overwrites a hand-set password on every switch.
- **Last checked**: 2026-09-13. Live password changed by the user. Cube
  **switched** the same day and the deployment was checked on the host:
  `/run/secrets/grafana-admin-password` is `grafana:grafana` mode `400`,
  the live `config.ini` references it, `grafana.service` is active with
  `NRestarts=0`, and `/run/current-system` matches what `experimental`
  evaluates to. **The value has still never been consumed** — cube's admin
  user predates it, so Grafana has not read the file and only a fresh
  instance would.

### 9. Syncthing device certificates

- **What**: the `syncthing-*` secrets in `secrets.yaml` (one per device:
  `durandal`, `galatea`, `lysithea`, `sif`, `iona`, `tenacity`). **Declared
  by no module since 2026-09-08** — `sops.nix` held five of them and now
  holds no `sops.secrets.*` at all; the keys stay in `secrets.yaml`
  unreferenced. Nothing decrypts them, so nothing breaks when they age.
- **Expiry**: Syncthing generates its own self-signed device certificate
  with a long validity (on the order of decades) and doesn't require manual
  renewal in normal operation. Listed here for completeness, not because
  anything is due — **no action expected** on any realistic timeline for
  this fleet.
- **Last checked**: 2026-09-07 (documentation check against Syncthing's own
  behavior, not a live cert inspection).

### 10. GitHub credential for the weekly lock PR

- **What (since 2026-09-16)**: elly's existing `gh auth` OAuth login on
  `nire-cube` (`hosts.yml`, scopes `repo`, `workflow`, `gist`,
  `read:org`), consumed where it already lived by
  [flake/scripts/lock-bump.sh](<../flake/scripts/lock-bump.sh>) — the
  weekly `flake.lock` bump that runs as cube's `flake-lock-bump` timer
  ([lock-bump.md](categories/lock-bump.md), #205) and opens the
  `chore: update flake.lock` PR against `experimental`. `push: true` on
  this repo, verified 2026-09-16.
- **What it replaced, in two hops**: the `update-flake-lock` workflow
  (2026-09-08 → 2026-09-16, deleted by #205) read the repo secret
  `FLAKE_LOCK_TOKEN` — a fine-grained PAT, minted 2026-09-13, updated
  2026-09-14, expiry 2027-09-12, proven by lock PRs #308 and #333 both
  merging. The first #205 design moved that PAT into `secrets.yaml` as
  `flake-lock-token`; superseded the same day by the gh-login design, so
  **no sops key was ever added** and no PAT needs minting.
- **Why gh's login and not a dedicated PAT**: the write-only Actions
  secret could not be read back, so the sops shape meant minting yet
  another PAT and hand-setting it before cube's next build would succeed —
  while a working credential with the needed scopes already sat on the
  same box, in the same user's config, for the same person. Reusing it
  adds no new exposure and deletes the manual step. Trade accepted:
  `repo` is broader than a repo-scoped fine-grained PAT; and the OAuth
  token has no expiry, so the weekly preflight's early warning degrades
  to "cannot tell" (logged notice, not a failure — the same best-effort
  gap the workflow documented for no-expiry tokens).
- **This one still fails loudly, by construction** — ported into
  `lock-bump.sh`: dead/rejected credential → hard fail at the token
  preflight before any nix work; `OnFailure=` → an alert unit files the
  reusable issue `update-flake-lock: weekly lock PR needs attention`.
  If the gh login itself is gone, the alert says so in the journal (it
  cannot file an issue without a token).
- **Failure mode if it lapses anyway**: `update_flake_lock_action` ahead
  of `experimental` with no PR attached, plus that issue. Fix:
  `gh auth login` as elly on cube, rerun `systemctl start
  flake-lock-bump`.
- **Cleanup owed**: delete the `FLAKE_LOCK_TOKEN` Actions secret after
  cube's first successful run (kept as rollback until then).
- **Last checked**: 2026-09-16 — gh login verified (`gh auth status`,
  API permissions); the sops redesign was backed out before it ever
  shipped; end-to-end on cube still pending first scheduled run.

### 11. Atuin account encryption key

- **What**: the local key (`~/.local/share/atuin/key`) that encrypts shell
  history before it's synced through Atuin's zero-knowledge server. Not in
  `secrets.yaml` — generated by `atuin register`, not sops-managed. Config
  lives in
  [`packages/shell-apps/history/atuin.nix`](../flake/modules/packages/shell-apps/history/atuin.nix).
- **Expiry**: none — doesn't expire, but the server has no key of its own
  to rotate, so "rotate the account's key" means wipe-and-re-push, not a
  server-side operation. See the procedure below for why.
- **Procedure**:
  [`atuin-key-rotation.md`](../flake/modules/packages/shell-apps/history/atuin-key-rotation.md),
  tucked next to `atuin.nix` above — the full `atuin account delete` /
  `atuin register` / `atuin sync` sequence lives there, not duplicated
  here.
- **Cadence**: no fixed schedule; rotate on suspicion of compromise (a
  device the key lived on lost or stolen), same as items 5 and 6 above.
- **Last checked**: 2026-09-09 — no rotation has happened yet; this is the
  first time the procedure was written down.

### 12. `nire-galatea/tskey` — a dead Tailscale auth key in git history

- **What**: an auth key file committed 2024-01-29 (`449d158`, "struggling
  with sops again") while `nire-galatea/` — a host long since removed from
  the fleet — was still in the tree; the file left the tree again later
  that year. It exists only in git history now, reachable from every
  branch. Listed here so the next scanner flag finds a decision instead of
  re-deriving one — not because anything is due, the same shape as item 9.
- **Expiry**: dead twice over. Rotated at the time (2024, per the user),
  and Tailscale auth keys can't outlive 90 days regardless. The repo is
  public, so the blob has been public since the day it was pushed — the
  exposure window closed years before anyone flagged it again.
- **Decision, 2026-09-14: left in place; history rewrite considered and
  rejected.** Purging it means force-pushing `main` and `experimental`
  (both ruleset-protected), invalidating every commit-SHA reference made
  since January 2024, and dropping the rewrite under whatever sessions are
  in flight — for a credential that cannot authenticate, in a repo where
  the old objects survive in existing clones and GitHub's caches no matter
  what (a true purge is a GitHub Support ticket even after a rewrite). The
  same public-repo permanence item 10 records for `secrets.yaml`'s
  ciphertext applies here.
- **What to do when a scanner flags it**: mark it rotated/false-positive
  and move on. The flag is expected noise, not a finding.
- **Last checked**: 2026-09-14 — decision made; no key material read, per
  `secrets-hygiene`.

## Adding a new item

When a change introduces a new credential, key, or certificate with any
expiry, rotation cadence, or silent-breakage property — add a row here in
the **same change**, same discipline `wiki-sync` already asks for elsewhere.
A secret with no such property (a static API token that never expires, say)
doesn't belong on this page; it just lives in `secrets.yaml`.

**A service left on vendor-default credentials belongs here too, and is
written as a live credential rather than a missing one** — it is a working
admin account with a publicly-known password, not an absence. Skill
`maintenance-schedule` has the required shape and why it exists.

## See also

- Skill [`maintenance-schedule`](../.agents/skills/maintenance-schedule/SKILL.md)
  — how to work through this page on a review pass, and what to do with
  each kind of finding.
- Skill [`secrets-hygiene`](../.agents/skills/secrets-hygiene/SKILL.md) —
  how to check or touch any of the underlying secrets without printing
  their plaintext.
- [Impermanence, initrd & secrets](impermanence-and-secrets.md) — the sops
  mechanism these age-key and rotation procedures build on.
- [homelab/backup-runbook.md](homelab/backup-runbook.md) — the actual
  rotation commands for the restic/QNAP items.
- [homelab/pending-setup.md](homelab/pending-setup.md) — one-time setup
  steps, as opposed to this page's recurring/expiring ones. An item can
  move from there to here once it's set up and now needs tending.

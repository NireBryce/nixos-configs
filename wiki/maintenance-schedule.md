# Maintenance schedule

_Last modified: 2026-09-08_

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
by skill [`maintenance-schedule`](../.claude/skills/maintenance-schedule/SKILL.md).

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
  see [`tailscale.nix`](../flake/modules/nire/system/networking/tailscale.nix)'s
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
  (`flake/modules/nire/system/secrets/.sops.yaml`) are each derived from
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

- **What**: still on initial/default setup — this is not yet a "rotate
  periodically" item because it hasn't had its one-time setup done at all.
- **Status**: see [homelab/pending-setup.md](homelab/pending-setup.md#5-grafanas-admin-credentials)
  for the current state. Once real credentials are set, add them here with
  the same shape as `forgejo-admin-password` above — this row should stop
  saying "pending" the same change that closes that pending-setup item.
- **Last checked**: 2026-09-07 (cross-referenced against pending-setup.md,
  not the live instance).

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

### 10. `FLAKE_LOCK_TOKEN` — GitHub PAT for the weekly lock PR

- **What**: a repo secret on `NireBryce/nixos-configs` (GitHub Actions
  secret, *not* in `secrets.yaml`) holding a fine-grained PAT scoped to
  this repo with `Contents: read/write` and `Pull requests: read/write`.
  Read by
  [`.github/workflows/update-flake-lock.yml`](../.github/workflows/update-flake-lock.yml)
  as the `token` input to `DeterminateSystems/update-flake-lock`.
- **Why a PAT and not `GITHUB_TOKEN`**: the repo setting that would let
  Actions open PRs is a single switch granting create **and** approve, and
  only create is wanted. A PAT acts as the repo owner, and GitHub refuses
  to let anyone approve a PR they authored — so the identity opening these
  PRs structurally cannot approve them. It also makes CI actually run on
  them, which a `GITHUB_TOKEN`-opened PR does not.
- **Expiry**: fine-grained PATs **must** carry an expiry; GitHub's own
  maximum for a custom date is 366 days, and the UI's default when created
  is 30 days. Whichever was picked, the date is visible at
  [github.com/settings/personal-access-tokens](https://github.com/settings/personal-access-tokens)
  — record it here once set.
- **Failure mode if it expires**: the Monday run pushes the updated
  `update_flake_lock_action` branch as normal and then fails at PR
  creation, exactly as the 2026-09-07 run did for the permission reason.
  **Silent unless someone looks** — a failed scheduled workflow emails the
  repo owner, but nothing in the repo changes and no PR appears. The
  symptom to recognise: a `update_flake_lock_action` branch ahead of
  `experimental` with no PR attached.
- **Last checked**: not yet created as of 2026-09-08 — the workflow was
  wired for it in that change and falls back to `GITHUB_TOKEN` (and so
  fails at PR creation) until the secret exists.

## Adding a new item

When a change introduces a new credential, key, or certificate with any
expiry, rotation cadence, or silent-breakage property — add a row here in
the **same change**, same discipline `wiki-sync` already asks for elsewhere.
A secret with no such property (a static API token that never expires, say)
doesn't belong on this page; it just lives in `secrets.yaml`.

## See also

- Skill [`maintenance-schedule`](../.claude/skills/maintenance-schedule/SKILL.md)
  — how to work through this page on a review pass, and what to do with
  each kind of finding.
- Skill [`secrets-hygiene`](../.claude/skills/secrets-hygiene/SKILL.md) —
  how to check or touch any of the underlying secrets without printing
  their plaintext.
- [Impermanence, initrd & secrets](impermanence-and-secrets.md) — the sops
  mechanism these age-key and rotation procedures build on.
- [homelab/backup-runbook.md](homelab/backup-runbook.md) — the actual
  rotation commands for the restic/QNAP items.
- [homelab/pending-setup.md](homelab/pending-setup.md) — one-time setup
  steps, as opposed to this page's recurring/expiring ones. An item can
  move from there to here once it's set up and now needs tending.

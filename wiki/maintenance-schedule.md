# Maintenance schedule

_Last modified: 2026-09-11_

## Contents

- [What this is](#what-this-is)
- [Why this file is plaintext, not sops-encrypted](#why-this-file-is-plaintext-not-sops-encrypted)
- [Items](#items)
- [Adding a new item](#adding-a-new-item)
- [See also](#see-also)

> **Condensed version:**
> [maintenance-schedule-for-agents.md](maintenance-schedule-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

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

- **What**: a GitHub Actions repo secret on `NireBryce/nixos-configs`
  (**not** in `secrets.yaml` — see below), holding a fine-grained PAT
  scoped to this repo with
  `Contents: read/write` and `Pull requests: read/write`. Read by
  [`../.github/workflows/update-flake-lock.yml`](<../.github/workflows/update-flake-lock.yml>)
  as the `token` input to `DeterminateSystems/update-flake-lock`.
- **Why a PAT rather than `GITHUB_TOKEN`**: chiefly so these PRs trigger
  CI. A `GITHUB_TOKEN`-opened PR does not trigger this repo's own
  `pull_request` workflows, so `nix flake check + module tree` never
  reports — and the `experimental` ruleset *requires* it, making such a PR
  unmergeable without an admin bypass. Secondarily, it keeps the repo-wide
  "Allow GitHub Actions to create and approve pull requests" setting off,
  and it structurally cannot approve its own PRs (GitHub refuses
  self-approval). That setting is a single switch granting create **and**
  approve, with no way to have one without the other.
- **Why not sops**, asked 2026-09-08 and worth not re-deriving: a runner
  would need the age key to decrypt, and that key would itself have to be
  a GitHub Actions secret — one GitHub-stored credential swapped for
  another, plus a layer. Nor could a runner be enrolled: every key in
  [`.sops.yaml`](<../flake/modules/nire/system/secrets/.sops.yaml>) is
  derived from a *host's* `/etc/ssh/ssh_host_ed25519_key.pub`, and a
  runner is an ephemeral VM with no persistent host key. And nothing in
  the nix tree ever reads this token, so a `sops.secrets.*` entry for it
  would decrypt on three hosts with no use for it — the shape #203
  deleted. Minor point in the same direction: `secrets.yaml` is committed
  to a *public* repo, so its ciphertext is permanently public; an Actions
  secret is never published. The general rule this follows is the one in
  "Why this file is plaintext" above — the consumer picks the store.
- **Expiry**: fine-grained PATs must carry one. GitHub's maximum for a
  custom date is 366 days; the creation UI defaults to 30. **Record the
  actual date here once minted** — this entry deliberately does not guess
  it.
- **This one fails loudly, by construction.** Unlike everything else on
  this page, the workflow checks its own credential rather than relying on
  someone reading this file:
  - A **missing, revoked, or expired** token fails the run at its first
    step with a `::error::` annotation naming the secret and what to do —
    before the nix install and flake update, rather than as a bare 401
    inside the action much later.
  - **Within 30 days of expiry** it emits a `::warning::` and keeps going,
    so the lock update still happens. The window is 30 days because the
    workflow runs *weekly* — a shorter one could give only one or two
    chances to notice.
  - Either case also **opens an issue in this repo** (reusing one open
    issue titled `update-flake-lock: weekly lock PR needs attention`
    rather than filing weekly), because a red scheduled run only emails
    the repo owner and that is easy to miss months later.
  - One gap, stated rather than papered over: GitHub returns the
    `github-authentication-token-expiration` header only for tokens that
    *have* an expiry, so an absent header means "cannot tell", not
    "healthy". That case emits a `::notice::` and does **not** fail — so
    the early warning is best-effort, while the hard failure on an
    already-dead token is not.
- **Failure mode if it lapses anyway**: the run pushes the updated
  `update_flake_lock_action` branch as normal and then fails at PR
  creation. The symptom to recognise: that branch sitting ahead of
  `experimental` with no PR attached — exactly the state the 2026-09-07
  run left behind for the unrelated permission reason.
- **Last checked**: 2026-09-08 — workflow wired and its preflight logic
  verified against the live API (valid token → 200; revoked token → 401 →
  hard fail; header parse confirmed against a simulated response, since no
  expiring token was available to test with). **The secret itself did not
  exist yet at that point**; until it does, every run fails at the
  preflight step.

### 11. Atuin account encryption key

- **What**: the local key (`~/.local/share/atuin/key`) that encrypts shell
  history before it's synced through Atuin's zero-knowledge server. Not in
  `secrets.yaml` — generated by `atuin register`, not sops-managed. Config
  lives in
  [`nirePackages/shell-apps/history/atuin.nix`](../flake/modules/nirePackages/shell-apps/history/atuin.nix).
- **Expiry**: none — doesn't expire, but the server has no key of its own
  to rotate, so "rotate the account's key" means wipe-and-re-push, not a
  server-side operation. See the procedure below for why.
- **Procedure**:
  [`atuin-key-rotation.md`](../flake/modules/nirePackages/shell-apps/history/atuin-key-rotation.md),
  tucked next to `atuin.nix` above — the full `atuin account delete` /
  `atuin register` / `atuin sync` sequence lives there, not duplicated
  here.
- **Cadence**: no fixed schedule; rotate on suspicion of compromise (a
  device the key lived on lost or stolen), same as items 5 and 6 above.
- **Last checked**: 2026-09-09 — no rotation has happened yet; this is the
  first time the procedure was written down.

## Adding a new item

When a change introduces a new credential, key, or certificate with any
expiry, rotation cadence, or silent-breakage property — add a row here in
the **same change**, same discipline `wiki-sync` already asks for elsewhere.
A secret with no such property (a static API token that never expires, say)
doesn't belong on this page; it just lives in `secrets.yaml`.

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

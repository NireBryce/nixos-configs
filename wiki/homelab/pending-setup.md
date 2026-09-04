# Pending setup

## Contents

- [How this differs from open-threads.md](#how-this-differs-from-open-threadsmd)
- [1. Forgejo has no users, so nobody can log in](#1-forgejo-has-no-users-so-nobody-can-log-in)
- [2. Decided: mirror, not origin — 2026-09-03](#2-decided-mirror-not-origin--2026-09-03)
- [3. golink has no links yet](#3-golink-has-no-links-yet)
- [4. No backups exist for any of it](#4-no-backups-exist-for-any-of-it)
- [5. Grafana's admin credentials](#5-grafanas-admin-credentials)
- [6. Housekeeping on cube: one scratch directory left over](#6-housekeeping-on-cube-one-scratch-directory-left-over)
- [What's verified here](#whats-verified-here)
- [See also](#see-also)

Services that are **running but not finished** — configured, switched,
reachable, and still missing the human step that makes them useful. Every
item here is something to do *to a live service*, in a browser or over ssh,
not a change to `flake/modules/`.

Verified against the live instances on 2026-08-24; each item says how it was
checked, so a stale entry can be re-tested rather than guessed at.

## How this differs from open-threads.md

[open-threads.md](../open-threads.md) tracks the *repo's* loose ends —
todos left in code, upstream bugs, deferred design decisions, GitHub issues.
This page tracks the *fleet's*: one-time operational setup that no commit
will ever complete, because it lives in a service's own database rather than
in Nix.

An item can be on both. Backups are, because the tooling is a repo change
(issue [#87](https://github.com/NireBryce/nixos-configs/issues/87)) *and* a
restore drill nobody has run.

---

## 1. Forgejo has no users, so nobody can log in

**Status: should be resolved by the next switch, not yet confirmed.** As of
2026-08-24, `GET /git/api/v1/users/search` returned `{"data":[],"ok":true}`
and `/git/api/v1/repos/search` an empty list — the forge up, serving, and
completely empty, with registration closed so the first account needed a
manual command.

2026-08-26: that manual step is now automated. `forgejo-admin-bootstrap`
(see [git-forge](../categories/git-forge.md)) creates the `elly`/admin
account declaratively on activation, password from this repo's sops
secrets.

**Live-checked 2026-09-04**: `GET /git/api/v1/users/search` now returns
the `elly` account — the bootstrap ran and cube has switched with it. But
`last_login` on that account is the zero value
(`0001-01-01T00:00:00Z`) — nobody has actually signed into the web UI yet
— and the API's `is_admin` field reads `false` (likely just Forgejo
masking that field for an unauthenticated caller, not necessarily meaning
the bootstrap's `--admin` flag didn't take; unconfirmed either way without
logging in).

**Done when** you've actually signed in at
`https://ts-cube.moose-micro.ts.net/git/user/login` and confirmed the
account is really admin from inside the UI — the account existing isn't
the same as that.

Then, separately: add an SSH key under Settings → SSH keys if you want
`forgejo@ts-cube:…` clones. See [using the forge](forgejo.md) for why that
key authorizes `forgejo@ts-cube` and not `elly@ts-cube`.

## 2. Decided: mirror, not origin — 2026-09-03

- **As a mirror** — GitHub stays the origin, cube holds copies. Losing cube
  costs nothing. **Chosen**, while item 4 (backups) is still short of a
  proven restore.
- **As an origin** — things live here first. That's the useful version, and
  it's the one that shouldn't happen until backups exist.

Still open: zero repos actually pushed yet, mirror or not — this item only
settled *which mode*, not that anything's been done.

## 3. golink has no links yet

`http://go/.export` returns empty — the instance is authenticated and serving
but nothing has been created. Some obvious first ones, given what's now
running:

| Short | Target |
|---|---|
| `go/dash` | `https://ts-cube.moose-micro.ts.net/` |
| `go/git` | `https://ts-cube.moose-micro.ts.net/git/` |
| `go/graf` | `https://ts-cube.moose-micro.ts.net/grafana/` |

Creating them is the web UI at `http://go/`, or the `curl` form in
[creating go/ links](golinks.md) — read that page's `--post302` and delete
traps first, both of which have teeth.

**Done when** `go/dash` resolves from a second tailnet device, not just the
one that created it.

## 4. No backups exist for any of it

**The big one**, tracked as
[#87](https://github.com/NireBryce/nixos-configs/issues/87). `/var/lib/forgejo`,
`/var/lib/grafana`, `/var/lib/private/golink` and `/persist/` all have exactly
one copy each, still — the module below doesn't change that yet.

2026-08-28: the [backup](../categories/backup.md) category exists now
(restic to the QNAP). Originally a local-path repo on the QNAP NFS mount —
that failed for real (`mount.nfs: access denied by server`, the share's
export ACL never included cube), and as of 2026-08-31 the module switched
to SFTP instead, issue #87's original plan. SSH now works on the QNAP (a
dedicated key for this, confirmed authenticating by hand), but:

- ~~Neither sops secret has a value in this tree~~ — **set, 2026-08-30
  (`restic-cube-password`) and 2026-08-31 (`restic-cube-ssh-key`)**, and
  **live-confirmed working 2026-09-04**: the 2026-09-03 backup timer run
  succeeded end to end. Cube hasn't switched onto the newer path move
  (2026-09-03, `restic-backup` share) yet — see the runbook's step 4 for
  the migration that implies.
- **No QNAP-side snapshot schedule exists on the backup share** — the
  anti-deletion mitigation the module assumes but can't configure itself.
- ~~QuTS hero has no toggle to force key-only SSH auth~~ — **mitigated,
  2026-08-31**: port 22 is now LAN-blocked and tailnet-only (confirmed
  live), and QNAP's brute-force protection is on. See the runbook's setup
  step 3.

**The [backup runbook](backup-runbook.md) is the actual procedure** —
including all three of the above, checking status, running an ad hoc
backup, and the real "done" bar: **a restore actually performed**, one
Forgejo repo recovered. A restore nobody has run isn't a backup. This entry
stays the tracking summary; that page has the commands.

## 5. Grafana's admin credentials

Not verifiable from outside without logging in, so this is a "confirm",
not a finding: Grafana ships with a default `admin` account and prompts for a
change on first sign-in. Worth confirming that happened, since the tailnet is
the only thing in front of it.

Related and worth knowing before you start building dashboards: anything
edited in the Grafana UI lives **only** in cube's sqlite db — which is item 4's
problem — while anything under `monitoring`'s `_dashboards/` is provisioned
read-only from the Nix store. A dashboard you want to keep should end up in
the repo, not just in the UI.

## 6. Housekeeping on cube: one scratch directory left over

Mostly done already. As of 2026-08-24, `~/nixos-configs` evaluated to
exactly what was running (`toplevel.outPath` matched
`/run/current-system`), and was one docs-only commit behind. The leftover:
**`~/nixos-caddy-test`**, the rsync'd tree the Caddy/glance switches were
activated from — nothing depends on it now.

```sh
cd ~/nixos-configs && git pull
rm -rf ~/nixos-caddy-test           # after confirming outPath matches current-system
```

## What's verified here

Checked live on 2026-08-24 from `nire-lysithea` over the tailnet, and on cube
over ssh: Forgejo's users and repos APIs both returning empty, golink's
`.export` returning nothing, cube's checkout revision and its evaluated
`toplevel.outPath` versus `/run/current-system`, and `~/nixos-caddy-test`
still existing.

**Not verified:** Grafana's admin password (item 5 — that needs a login, not
a probe), and every command in this page. None of them has been run; they're
written from each service's own documentation and this repo's modules.

## See also

- [Reaching cube's services](reaching-services.md) — the URLs, and what to
  check when one doesn't answer.
- [Using the forge](forgejo.md) — clone URLs, sign-in, and the SSH key
  detail item 1 hands off to.
- [Creating go/ links](golinks.md) — the traps item 3 hands off to.
- [open-threads.md](../open-threads.md) — the repo-side counterpart to this
  page.

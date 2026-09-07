# Pending setup

_Last modified: 2026-09-06_

## Contents

- [How this differs from open-threads.md](#how-this-differs-from-open-threadsmd)
- [1. Done — Elly is signed in, confirmed 2026-09-05](#1-done--elly-is-signed-in-confirmed-2026-09-05)
- [2. Decided: mirror, not origin — 2026-09-03](#2-decided-mirror-not-origin--2026-09-03)
- [3. golink has no links yet](#3-golink-has-no-links-yet)
- [4. Done — backups exist, and a restore has actually recovered something](#4-done--backups-exist-and-a-restore-has-actually-recovered-something)
- [5. Grafana's admin credentials](#5-grafanas-admin-credentials)
- [6. Housekeeping on cube: one scratch directory left over — done](#6-housekeeping-on-cube-one-scratch-directory-left-over--done)
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

An item can be on both. Backups were, until 2026-09-06 — the tooling was a
repo change (issue [#87](https://github.com/NireBryce/nixos-configs/issues/87)),
and the restore drill it needed has since actually been run (twice: once
to find a real bug, once more to confirm the fix).

---

## 1. Done — Elly is signed in, confirmed 2026-09-05

As of 2026-08-24, `GET /git/api/v1/users/search` returned
`{"data":[],"ok":true}` — the forge up, serving, and completely empty,
with registration closed so the first account needed a manual command.
2026-08-26: `forgejo-admin-bootstrap` (see
[git-forge](../categories/git-forge.md)) automated that, creating the
`elly`/admin account declaratively on activation.

**A real gap in how this was checked, caught 2026-09-05**: the unauthenticated
`GET /git/api/v1/users/search` always reports `last_login` as the zero
value (`0001-01-01T00:00:00Z`) and `is_admin`/`active` as `false` —
Forgejo/Gitea's own anonymous-safe field masking, not a real read of
account state. Two agent sessions (2026-09-04, 2026-09-05) took that zero
value at face value and wrote "nobody has signed in yet" into this page
and the backup runbook — wrong both times, since a same-day screenshot
from Elly showed an active, logged-in session the whole time. The account
existing was real; the "hasn't logged in" conclusion drawn from an
anonymous API call was not. Re-running the same query afterward still
returns the same zero value even with Elly actively logged in, confirming
the field is simply not meaningful from this endpoint, not that anything
changed.

**Still open**: whether the account is *really* admin (bootstrap's
`--admin` flag) is unconfirmed either way — the masked `is_admin: false`
never proved or disproved it. Confirming it means checking the Site
Administration panel from inside the UI, not another anonymous API call.

Then, separately: add an SSH key under Settings → SSH keys if you want
`forgejo@ts-cube:…` clones. See [using the forge](forgejo.md) for why that
key authorizes `forgejo@ts-cube` and not `elly@ts-cube`.

## 2. Decided: mirror, not origin — 2026-09-03

- **As a mirror** — GitHub stays the origin, cube holds copies. Losing cube
  costs nothing. **Chosen**, 2026-09-03, before item 4's restore was
  proven — worth revisiting now that a real restore has actually
  succeeded, if an origin is wanted.
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

## 4. Done — backups exist, and a restore has actually recovered something

**The big one**, tracked as
[#87](https://github.com/NireBryce/nixos-configs/issues/87), closed
2026-09-06: a real restore of `/var/lib/forgejo`, `/persist/`, and
Forgejo's actual sqlite database has been performed and confirmed
recoverable — not just "a backup exists," the harder bar #87 always set.

2026-08-28: the [backup](../categories/backup.md) category exists now
(restic to the QNAP). Originally a local-path repo on the QNAP NFS mount —
that failed for real (`mount.nfs: access denied by server`, the share's
export ACL never included cube), and as of 2026-08-31 the module switched
to SFTP instead, issue #87's original plan. SSH now works on the QNAP (a
dedicated key for this, confirmed authenticating by hand), but:

- ~~Neither sops secret has a value in this tree~~ — **set, 2026-08-30
  (`restic-cube-password`) and 2026-08-31 (`restic-cube-ssh-key`)**, and
  **live-confirmed working 2026-09-05**: cube has switched onto the
  `restic-backup`-share path move, its timer has run successfully against
  it, and the pre-move repo's history (five snapshots, 2026-08-31 through
  2026-09-04) was migrated in with `restic copy` — six snapshots total,
  confirmed via a live listing. See
  [backup-history.md](../categories/backup-history.md).
- ~~No QNAP-side snapshot schedule exists on the backup share~~ — **done,
  2026-09-05**, confirmed via a Snapshot Manager screenshot: daily at
  04:30 on the `restic-backup` share, keeping 5 days, status Success, 2
  snapshots already taken.
- ~~QuTS hero has no toggle to force key-only SSH auth~~ — **mitigated,
  2026-08-31**: port 22 is now LAN-blocked and tailnet-only (confirmed
  live), and QNAP's brute-force protection is on. See the runbook's setup
  step 3.

**All setup is done, and the restore drill found a real bug — since fixed
and confirmed live.** The sqlite consistency mechanism
(`backupPrepareCommand`, meant to protect Forgejo/Grafana/golink's
databases specifically) had never actually worked: `restic ls --recursive`
against the repository showed it backed up completely empty in every real
run checked, including a fresh reboot. Root cause: the staging directory
lived inside restic's own cache directory, which restic refuses to back
up — confirmed with a clean before/after test. Fixed by moving it outside
that directory, then confirmed for real: a switch, a real backup run, and
a real restore that opened a genuine, complete Forgejo database (every
expected table present). Full account: **[backup
runbook](backup-runbook.md)** and `wiki/categories/backup.md`'s "The
sqlite consistency bug."

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

## 6. Housekeeping on cube: one scratch directory left over — done

As of 2026-08-24, `~/nixos-configs` evaluated to exactly what was running
(`toplevel.outPath` matched `/run/current-system`), and was one docs-only
commit behind. The leftover, **`~/nixos-caddy-test`** (the rsync'd tree the
Caddy/glance switches were activated from), has since been deleted, and the
real checkout is caught up with `main`.

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

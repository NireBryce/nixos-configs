# Pending setup

_Last modified: 2026-09-12_

Services that are **running but not finished** — configured, switched,
reachable, and still missing the human step that makes them useful. Every
item here is something to do *to a live service*, in a browser or over ssh,
not a change to `flake/modules/`.

Verified against the live instances on 2026-08-24; each item says how it was
checked, so a stale entry can be re-tested rather than guessed at.

> **Condensed version:**
> [pending-setup-for-agents.md](pending-setup-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [How this differs from open-threads.md](#how-this-differs-from-open-threadsmd)
- [1. An SSH key, if you want `forgejo@ts-cube` clones](#1-an-ssh-key-if-you-want-forgejots-cube-clones)
- [2. Mirror, or origin?](#2-mirror-or-origin)
- [3. golink has no links yet](#3-golink-has-no-links-yet)
- [4. Done — backups exist, and a restore has actually recovered something](#4-done--backups-exist-and-a-restore-has-actually-recovered-something)
- [5. Grafana's admin credentials](#5-grafanas-admin-credentials)
- [6. Done — housekeeping on cube, 2026-08-24](#6-done--housekeeping-on-cube-2026-08-24)
- [7. Homepage's calendar feeds](#7-homepages-calendar-feeds)
- [What's verified here](#whats-verified-here)
- [See also](#see-also)

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

## 1. An SSH key, if you want `forgejo@ts-cube` clones

**The admin question is settled: `elly` is admin — confirmed by Elly
2026-09-12.** `forgejo-admin-bootstrap`'s `--admin` flag took. The account
bootstrap and the anonymous API that made two sessions report otherwise are
recorded in
[git-forge-history.md](../categories/git-forge-history.md#the-admin-account-and-an-anonymous-api-that-reports-zeroes).

**What is still open:** add an SSH key under Settings → SSH keys if you want
`forgejo@ts-cube:…` clones. See [using the forge](forgejo.md) for why that
key authorizes `forgejo@ts-cube` and not `elly@ts-cube`.

## 2. Mirror, or origin?

The "is anything actually mirrored" half is done and moved to
[git-forge-history.md](../categories/git-forge-history.md#mirror-not-origin--and-the-first-real-mirror)
2026-09-12: this repo is a genuine Forgejo pull mirror as of 2026-09-11, all
7 branches confirmed matching GitHub.

**What is still open:** mirror was chosen 2026-09-03 explicitly *before*
item 4's restore was proven, on the reasoning that an origin shouldn't exist
until backups do. Backups now exist and a real restore has recovered a real
database, so the condition that decided this has been met — worth revisiting
if an origin is wanted. Nothing forces the change; it is a live option, not
a task.

## 3. golink has no links yet

`http://go/.export` returns empty — the instance is authenticated and serving
but nothing has been created. Some obvious first ones, given what's now
running:

| Short | Target |
|---|---|
| `go/dash` | `https://homepage.moose-micro.ts.net/` |
| `go/git` | `https://git.moose-micro.ts.net/` |
| `go/graf` | `https://grafana.moose-micro.ts.net/` |

These targets were updated 2026-09-11 from the retired path-prefix URLs
(`ts-cube.moose-micro.ts.net/git/` and friends) to each service's own
Tailscale Services name, and `go/dash` re-pointed 2026-09-12 from the
retired `glance.` name to homepage (issue #291). Nothing needed
re-pointing for real: `http://go/.export` is still empty, so these remain
proposals rather than links that exist. One homepage-specific item joined
this list with #291 — see the calendar-feeds entry below.

Creating them is the web UI at `http://go/`, or the `curl` form in
[creating go/ links](creating-golinks.md) — read that page's `--post302` and delete
traps first, both of which have teeth.

**Done when** `go/dash` resolves from a second tailnet device, not just the
one that created it.

## 4. Done — backups exist, and a restore has actually recovered something

Closed 2026-09-06, tracked as
[#87](https://github.com/NireBryce/nixos-configs/issues/87). A real restore
of `/var/lib/forgejo`, `/persist/` and Forgejo's actual sqlite database was
performed and confirmed recoverable — the harder bar #87 always set, not
merely "a backup exists". The drill found a real bug in the sqlite staging
mechanism, since fixed and confirmed live.

The full setup account — the two sops secrets, the QNAP snapshot schedule,
the SSH-auth limitation — moved to
[backup-history.md](../categories/backup-history.md#the-setup-checklist-closed-out-2026-08-28-through-2026-09-06)
2026-09-12. The procedure is [backup-runbook.md](backup-runbook.md).

## 5. Grafana's admin credentials

Not verifiable from outside without logging in, so this is a "confirm",
not a finding: Grafana ships with a default `admin` account and prompts for a
change on first sign-in. Worth confirming that happened, since the tailnet is
the only thing in front of it.

Related and worth knowing before you start building dashboards: anything
edited in the Grafana UI lives **only** in cube's sqlite db, while anything
under `monitoring`'s `_dashboards/` is provisioned read-only from the Nix
store. That db is backed up now (item 4, done), so a UI dashboard survives
a *restore* — but it still isn't declared as code, so it still can't
survive a *rebuild* that reprovisions `_dashboards/`. A dashboard you want
to keep permanently should end up in the repo:
[monitoring.md](../categories/monitoring.md#adding-a-dashboard-that-survives-a-rebuild)
has the how-to, not yet verified against a real UI export.

## 6. Done — housekeeping on cube, 2026-08-24

`~/nixos-caddy-test` (the rsync'd tree the Caddy/glance switches were
activated from) has been deleted, and the real checkout is caught up. Kept
as a one-line record rather than moved: there is no `housekeeping` category
for it to have a history page in, and the outcome is the whole story.

## 7. Homepage's calendar feeds

Configured end to end with #291 — the calendar/agenda widgets, the
`homepage-env` sops key, the `{{HOMEPAGE_VAR_ICAL_*}}` plumbing — except the
one thing only a human can supply: the **actual gcal secret iCal
addresses**. Calendar IDs were deliberately not assigned at implementation.
Until they are, the calendars render as a bare month grid and an empty
agenda, and each calendar card carries a small API-error band — the
placeholder URL 403ing, gone the moment a real address takes its place
(the secret's `restartUnits` bounces homepage at the next switch).

The fill-in: `sops <repo>/flake/modules/nire/system/secrets/secrets.yaml`,
edit the `homepage-env` value to one
`HOMEPAGE_VAR_ICAL_<NAME>=<secret-ics-url>` line per calendar (`family`
exists as the placeholder name; more names mean adding entries to
`homepage.nix`'s `calendars` attrset too). The secret's `restartUnits`
bounces homepage-dashboard on the next switch; events then appear with no
further commit. Where the addresses come from: Google Calendar → Settings
→ "Secret address in iCal format", per calendar. Mechanism and traps:
[categories/landing.md](../categories/landing.md#how-the-gcal-calendar-feeds-work).

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
- [Creating go/ links](creating-golinks.md) — the traps item 3 hands off to.
- [open-threads.md](../open-threads.md) — the repo-side counterpart to this
  page.

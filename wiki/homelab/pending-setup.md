# Pending setup

_Last modified: 2026-09-26_

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
- [1. Done — SSH key added, clone over SSH confirmed 2026-09-13](#1-done--ssh-key-added-clone-over-ssh-confirmed-2026-09-13)
- [2. Done — mirror, reaffirmed 2026-09-12](#2-done--mirror-reaffirmed-2026-09-12)
- [3. golink has no links yet](#3-golink-has-no-links-yet)
- [4. Done — backups exist, and a restore has actually recovered something](#4-done--backups-exist-and-a-restore-has-actually-recovered-something)
- [5. Grafana's admin credentials](#5-grafanas-admin-credentials)
- [6. Done — housekeeping on cube, 2026-08-24](#6-done--housekeeping-on-cube-2026-08-24)
- [7. Homepage's calendar feeds](#7-homepages-calendar-feeds)
- [8. Done — Forgejo Actions runner, first green run 2026-09-26](#8-done--forgejo-actions-runner-first-green-run-2026-09-26)
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

## 1. Done — SSH key added, clone over SSH confirmed 2026-09-13

The user's key was already added; auth and a real clone were both exercised from
`nire-tenacity` on 2026-09-13:

```
$ ssh -T forgejo@ts-cube
Hi there, elly! You've successfully authenticated with the key named
elly@nire-tenacity, but Forgejo does not provide shell access.
$ git clone --depth 1 forgejo@ts-cube:elly/nixos-configs.git
```

The key is `~/.ssh/id_ed25519` (`elly@nire-tenacity`), not a dedicated one,
and no `ssh_config` block was needed. **Push over SSH is still untested.**

**It is your own key, not a key belonging to the `forgejo` account** — the
`forgejo@` in the clone URL is the account SSH connects *to*, which has no
keypair of its own. Procedure, for the next key or the next person:
[forgejo.md → Adding one](forgejo.md#adding-one).

(The admin half of this item is settled — `elly` is admin, confirmed
2026-09-12; the account bootstrap and the anonymous API that reported
otherwise are in
[git-forge-history.md](../categories/git-forge-history.md#the-admin-account-and-an-anonymous-api-that-reports-zeroes).)

## 2. Done — mirror, reaffirmed 2026-09-12

**Cube stays a mirror. GitHub remains canonical.** Decided 2026-09-03 and
reaffirmed by the user 2026-09-12 — this time with the condition that had
gated it actually met, rather than in place of it: an origin was always
held back until backups existed, and a real restore has since recovered a
real database (item 4). The answer did not change.

The record — the choice, and this repo becoming the first thing actually
mirrored on 2026-09-11 — is in
[git-forge-history.md](../categories/git-forge-history.md#mirror-not-origin--and-the-first-real-mirror).
Reopening it is a fresh decision, not an outstanding one.

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

**Both halves done 2026-09-13.**

**The live password was changed by hand**, by the user, through the UI. It
persists: `grafana.nix` declares no drift enforcement, cube has a plain
persistent root, so `/var/lib/grafana`'s sqlite db keeps it across reboots
and rebuilds, and restic covers it.

**A fresh instance can no longer fail open.** `grafana.nix` now sets
`settings.security.admin_password` from the new `grafana-admin-password`
sops secret via Grafana's `$__file{}` provider. Before this, a rebuilt or
newly-provisioned Grafana came up on the published `admin`/`admin` with only
the tailnet in front of it, and stayed there until a human noticed.

**What this deliberately does not do:** manage the running instance's
password. Grafana's own `defaults.ini` says `admin_password` "can be changed
before first start of grafana, or in profile settings" — it applies when
Grafana *creates* the admin user, so on an instance that already has one it
is inert. Making sops authoritative over a live password needs a different
mechanism (a oneshot running `grafana-cli admin reset-admin-password`, the
shape `forgejo-admin-bootstrap` uses), which would overwrite a hand-set
password on every switch. Not done on purpose.

**Switched on cube 2026-09-13.** What that confirmed, checked on the host
rather than inferred:

- `/run/secrets/grafana-admin-password` exists as `grafana:grafana` mode
  `400` — the `owner =` in the module is right in practice, not just in
  `nix eval`, which is the half this module's `secret_key` history got
  wrong once.
- Grafana's live `config.ini` carries
  `admin_password=$__file{/run/secrets/grafana-admin-password}`.
- `grafana.service` is active with `NRestarts=0`, so it took the new config
  without crash-looping.
- `/run/current-system` matches what `experimental` evaluates to.

**The first-start path is still unexercised, and that is expected.** Cube's
admin user predates this, so Grafana has never read the file. The sops value
has never been consumed by anything; it is deployed, not proven. Only a
fresh instance — a rebuilt cube, or a wiped `/var/lib/grafana` — actually
uses it.

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

The fill-in: `sops <repo>/flake/modules/config-system/system/secrets/secrets.yaml`,
edit the `homepage-env` value to one
`HOMEPAGE_VAR_ICAL_<NAME>=<secret-ics-url>` line per calendar (`family`
exists as the placeholder name; more names mean adding entries to
`homepage.nix`'s `calendars` attrset too). The secret's `restartUnits`
bounces homepage-dashboard on the next switch; events then appear with no
further commit. Where the addresses come from: Google Calendar → Settings
→ "Secret address in iCal format", per calendar. Mechanism and traps:
[categories/landing.md](../categories/landing.md#how-the-gcal-calendar-feeds-work).

## 8. Done — Forgejo Actions runner, first green run 2026-09-26

The runner VM went live on cube 2026-09-25, and its first real job
(`elly/nire-skills`, run 2) passed 2026-09-26. Nothing is left to fill in
by hand: since 2026-09-26 cube generates a fresh single-use secret for
every job (`forge-runner-cycle`, [git-forge](../categories/git-forge.md)),
so the one-time secret-and-UUID procedure this item used to hold no
longer applies. The sops key `forgejo-runner-secret` it created is unused
and due for removal.

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

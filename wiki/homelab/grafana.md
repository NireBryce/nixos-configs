# Using Grafana

_Last modified: 2026-09-26_

Grafana on `nire-cube`, showing the metrics
[monitoring](../categories/monitoring.md) collects. This page is about
**using** it — signing in, and what happens to a dashboard you make. That
page is how it's configured and why.

## Contents

- [Where it is](#where-it-is)
- [Signing in: two passwords that don't talk to each other](#signing-in-two-passwords-that-dont-talk-to-each-other)
- [A dashboard you edit in the UI is not in the repo](#a-dashboard-you-edit-in-the-ui-is-not-in-the-repo)
- [Alerts](#alerts)
- [What's backed up](#whats-backed-up)
- [What's verified here](#whats-verified-here)
- [See also](#see-also)

## Where it is

`https://grafana.moose-micro.ts.net/`, short form `http://grafana/` — type
the short one with `http://`, not `https://`, per
[reaching cube's services](reaching-services.md). Tailnet only; Grafana
itself binds loopback and Caddy is its only client.

## Signing in: two passwords that don't talk to each other

This is the part worth reading before you touch anything.

**The password you actually log in with** was set by hand through the UI on
2026-09-13. It lives in Grafana's sqlite db at `/var/lib/grafana` on cube.
Cube has a plain persistent root, so it survives reboots and rebuilds of the
*system*, and restic backs it up. It is **not reproducible**: nothing in this
repo can recreate it.

**A separate password lives in sops** as `grafana-admin-password`, wired to
`settings.security.admin_password`. Grafana reads it **only when it creates
the admin user** — its own `defaults.ini` says "can be changed before first
start of grafana, or in profile settings". It exists so a *fresh* instance
can't come up on the published `admin`/`admin` the way this one originally
did, with the tailnet as the only thing in front of it.

So:

| | which password |
|---|---|
| Logging in today | the hand-set one, in cube's sqlite db |
| A rebuilt cube, or a wiped `/var/lib/grafana` | the sops one |

**Nothing reconciles the two, and nothing warns you.** Changing one does not
change the other; they are free to diverge indefinitely, and the only moment
the difference shows up is a first start you probably weren't planning. If
you change the UI password, change the sops value too unless you want a
rebuilt instance to come back on something you've forgotten. Rotating the
sops half is `sops set` — [backup-runbook.md](backup-runbook.md)'s "Rotating
the secrets" has the shape, and never pipe `sops -d` anywhere.

Making sops authoritative over the live password is possible — a oneshot
running `grafana-cli admin reset-admin-password` every activation, the way
Forgejo's admin bootstrap works — and is deliberately not done, because it
would overwrite a hand-set password on every `switch`.

## A dashboard you edit in the UI is not in the repo

Two kinds of dashboard exist here and they behave differently:

- **Provisioned** — anything under the module's `_dashboards/`, read-only
  from the Nix store. Declared as code, reproducible, and **not editable in
  the UI** (Grafana will let you change the view but not save over it).
- **UI-made** — anything you build in the browser. Stored only in cube's
  sqlite db.

A UI dashboard **survives a restore** (the db is backed up) but **not a
rebuild that reprovisions** `_dashboards/`. If you want to keep one, it has
to end up in the repo:
[monitoring.md's how-to](../categories/monitoring.md#adding-a-dashboard-that-survives-a-rebuild)
covers exporting it to JSON and adding it — **not yet verified against a
real UI export**, so expect to correct it the first time someone tries.

## Alerts

**Alerting → Alert rules** has six provisioned rules. Folder `cube` has one:
cube's root filesystem under 10% free. Folder `forge-runner` has five
about the Forgejo runner VM. All are defined in
`monitoring/runner-alerts/runner-alerts.nix`:

- a job connecting outside the egress allowlist;
- a job connecting to a private or tailnet range;
- refused DNS lookups;
- the guest failing to boot;
- the runner cycle or its DNS resolver not running.

Each rule's description says where to look next, usually a `journalctl`
command on cube. Provisioned rules can't be edited in the UI; change them
in that file. Which contact point receives them is set under
**Alerting → Contact points**.

## What's backed up

Grafana's db is inside the restic backup of cube's service state, along with
Forgejo's and golink's — see the [backup runbook](backup-runbook.md).

The caveat that bites on restore: the live `.db` files are **excluded from
every snapshot on purpose**, because a live sqlite file can be mid-write when
restic reads it. The restorable copy is the staged one under
`/var/lib/restic-backups-cube-sqlite-staging`. Restore the wrong path and you
get a file that is present and opens as nothing.

## What's verified here

- The sops secret is **deployed and never consumed**, confirmed on cube
  2026-09-13: `/run/secrets/grafana-admin-password` is `grafana:grafana`
  mode `400`, the live `config.ini` carries
  `admin_password=$__file{/run/secrets/grafana-admin-password}`, and
  `grafana.service` is active with `NRestarts=0`. Grafana has still never
  read that file — the admin user predates it.
- **Never exercised:** a first start against the sops value, the
  export-a-dashboard-to-JSON path above, and a restore of Grafana's db
  specifically (the 2026-09-06 restore drill opened Forgejo's).

## See also

- [monitoring](../categories/monitoring.md) — configuration, the
  `secret_key` trap, and the dashboard how-to.
- [maintenance-schedule.md](../maintenance-schedule.md) — item 8, both
  passwords and what would unify them.
- [Reaching cube's services](reaching-services.md) — names, TLS, and what to
  check when something doesn't answer.
- [Backup runbook](backup-runbook.md) — restoring, and rotating sops values.

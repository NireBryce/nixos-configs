# Pending setup

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
secrets. `just preflight` passes, but this hasn't gone through a real
`switch` on cube yet — the users API call above hasn't been re-run since.

**Done when** you can sign in at
`https://ts-cube.moose-micro.ts.net/git/user/login` and the users API returns
something — re-check after the next `switch`, don't assume this item is
closed just because the module landed.

Then, separately: add an SSH key under Settings → SSH keys if you want
`forgejo@ts-cube:…` clones. See [using the forge](forgejo.md) for why that
key authorizes `forgejo@ts-cube` and not `elly@ts-cube`.

## 2. Nothing has been pushed to the forge, and what it's *for* isn't decided

Zero repos. Worth settling before the first push, because it changes how much
the missing backups matter:

- **As a mirror** — GitHub stays the origin, cube holds copies. Losing cube
  costs nothing. This is the safe default while item 4 is open.
- **As an origin** — things live here first. That's the useful version, and
  it's the one that shouldn't happen until backups exist.

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
(restic, local-path repo on the already-imported QNAP NFS mount, not the
issue's original SFTP sketch — see that page for why). The secret, build,
and switch are all done as of 2026-08-30 — what's actually stopping it from
being a real backup now:

- **The QNAP is refusing the NFS mount** — `mount.nfs: access denied by
  server`, a real error from cube's journal once the switch made the
  automount unit live. Almost certainly the `restic-backup` share's NFS
  host-access list not including cube yet, since it's a share created just
  for this. Fix is in the QNAP's own admin web console.
- **SSH into the QNAP doesn't work** (checked from the LAN and the tailnet
  both), so that fix can't be scripted or done from a shell — Telnet/SSH
  is very likely just off in QTS, its own default.
- **No QNAP-side snapshot schedule exists on the backup share** — the
  anti-deletion mitigation the module assumes but can't configure itself.

**The [backup runbook](backup-runbook.md) is the actual procedure**,
including the current blocker's diagnosis, checking status, running an ad
hoc backup, and — the real "done" bar — performing a restore. This entry
stays the tracking summary; that page is where the commands and the live
error text live.

Once the NFS access rule is fixed: **done still means a restore actually
performed** — one Forgejo repo recovered from the backup — because a
restore nobody has run isn't a backup, and neither is a mount that still
fails.

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

Mostly done already. As of 2026-08-24:

- `~/nixos-configs` is at `25b6bfb0`, and evaluates to
  `l9iy6agb…-nixos-system-nire-cube`, which is **exactly what's running** —
  checked by evaluating `toplevel.outPath` there and comparing to
  `/run/current-system`. So switching from that checkout is a no-op, not a
  risk.
- It is one commit behind `main` (`dbfa80b5`, the `new-homelab-service`
  skill). Docs only — it changes no host's system.
- **`~/nixos-caddy-test` is still present.** That's the rsync'd working tree
  the Caddy and glance switches were actually activated from, kept while they
  were being verified. Nothing depends on it now.

```sh
cd ~/nixos-configs && git pull      # picks up the skill commit
rm -rf ~/nixos-caddy-test           # after confirming the above outPath matches
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

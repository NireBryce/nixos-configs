---
name: new-homelab-service
description: How to add a self-hosted network service to a host in this repo and verify it actually works.
---

# Adding a homelab service in this repo

## Applies to

Adding a service that listens on a port and is meant to be reached from
another machine — Grafana, Forgejo, golink, glance, Caddy (all on
`nire-cube`). Use before creating the category: some decisions are hard to
undo once a service is live and has state.

A service *is* a flake module, so `new-flake-module`'s rules still apply;
this skill is the layer above — which category, which port, how it's
reached, what "working" means. Also: `nirepackages-platform-support` for
packages, `new-host-config` for hosts (VMs have no skill; see
`wiki/categories/virtualization.md`).

Three of the five existing services broke on first switch for reasons
invisible to eval, build, and even reading the artifact — the secret file's
owner (Grafana), a missing `AF_NETLINK` (golink), a proxy prefix the app
didn't want (Forgejo). See `wiki/lessons-learned.md` §§36, 37, 40, 41; the
checklist below is mostly their accrued cost.

## The shape

One commit: a category dir `flake/modules/nire/<category>/` with a copy of
`dirsAsCategory.nix`; one module `<category>/<tool>/<tool>.nix`; one
commented line in the host's config; a Caddy route if HTTP; docs
(`wiki/categories/<category>.md` + indexes).

## 1. Check nixpkgs for a module before writing a unit

```sh
NP=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./flake)).inputs.nixpkgs.outPath')
ls $NP/nixos/modules/services/*/ | grep -i <tool>
```

Four of the five services set options on an upstream module. `golink` is the
exception — no `services.golink` exists, `golink.nix` hand-writes its unit,
and it's the one that failed on a hardening knob. A hand-written unit is
much higher risk; expect the first switch to fail and plan the runtime check
for it.

## 2. Name the category after the function, never the tool

A category and module sharing a name both declare
`flake.modules.nixos.<name>` and **silently merge** (happened for real with
`containers`/`podman.nix`; caught by `just modules` twice mid-write).

| category | module | why not the obvious name |
|---|---|---|
| `git-forge` | `forgejo` | `forgejo`/`forgejo` merges |
| `shortlinks` | `golink` | and not `golinks` — one letter off reads as a typo |
| `reverse-proxy` | `caddy` | `caddy`/`caddy` merges |
| `landing` | `glance` | and not `dashboard` — `monitoring` is full of Grafana dashboards |
| `monitoring` | 5 modules | — |

Run `just modules` immediately after creating the directory; it's the only
thing that catches this.

## 3. Pick a port from the actual registry

A collision is a bind failure at start, not an eval error — nothing catches
it until the switch.

| port | what | binding |
|---|---|---|
| 3000 | Grafana | loopback |
| 3001 | Forgejo | loopback |
| 3002 | glance | loopback |
| 8080 | cadvisor | loopback |
| 9090 | Prometheus | loopback |
| 9100 | node-exporter | loopback |
| 9177 | libvirt-exporter | loopback |
| 80, 443 | Caddy | all interfaces |

Take the next free `300x` for anything user-facing. Grep before trusting
this table:

```sh
grep -rnE '\b(30[0-9]{2}|80[0-9]{2}|9[0-9]{3})\b' flake/modules/nire/ | grep -iE 'port'
```

Never accept a tool's default unchecked — glance defaults to 8080, which
cadvisor already holds.

## 4. Bind loopback, add nothing to the firewall

New services bind `127.0.0.1` and are reached through Caddy — not
`0.0.0.0`-plus-`trustedInterfaces` (a firewall property, not a listener
property; how Grafana and Forgejo were originally written). No new
`networking.firewall.allowedTCPPorts`: cube's only tailnet-facing ports are
Caddy's 80/443.

Exception: a service not on the host's network at all — golink embeds tsnet
and joins the tailnet as its own device (`go`), so no port, no firewall rule,
no Caddy route, no host `tailscaled`.

## 5. The prefix question — settle before the first switch

MagicDNS gives one name per device, so HTTP services mount under a path
prefix on `ts-cube.moose-micro.ts.net`. **Apps disagree about who strips the
prefix** (§41, cost a switch):

- App serves under a subpath (Grafana's `serve_from_sub_path`) → Caddy
  `handle`, prefix kept.
- App always serves at `/` (Forgejo, regardless of `ROOT_URL`) → Caddy
  `handle_path`, prefix stripped; the app's base-URL setting then only
  controls links it generates.

Settle against the running service, not the docs:

```sh
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<port>/
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<port>/<prefix>/
```

Root 200 + prefix 404 → `handle_path`. Caddyfile mechanics that bite:
`handle` takes **one** matcher token (`handle /a /a/*` is a parse error;
two paths need a named matcher `@a path /a /a/*`), and `handle_path` takes
an inline path matcher only, so a bare `/a` needs its own `redir` to `/a/`.
A service at `/` (glance) sidesteps all of this.

## 6. Does the upstream module handle its own secrets?

`services.forgejo` generates its own secrets on first activation — nothing
to do. `services.grafana` deliberately doesn't (nixpkgs removed its
`secretKeyFile`), and the hand-created file was found unreadable twice. If a
secret must exist on disk: a oneshot ordered before the service that creates
it only when missing and reasserts owner/mode every activation —
`grafana-secret-key-setup.service` in `grafana.nix` is the worked example.
Never regenerate an existing secret (Grafana's `secret_key` overwrite breaks
decryption of its whole database). A `warnings` entry naming a manual
command is not a fix — that's what regressed before.

## 7. Persistence

`nire-cube` has a plain persistent root — `/var/lib/<service>` survives on
its own, none of the five modules has a `*-persist.nix`. If a host that
wipes `/root` (durandal, tenacity) ever imports a service module, add a
persistence entry **first**, modeled on `tailscale-persist.nix`, filed next
to the module (not under `nire/impermanence/` — see `WARN-impermanence.nix`).
All five module headers state which case applies; keep that.

## 8. Verify, in the order that finds things

Skipping rungs is fine; claiming a rung you didn't run is not.

1. `git add` first — flakes ignore untracked files; a new module silently
   doesn't exist.
2. `just modules` — collisions and orphans.
3. `nix eval` the toplevel drvPath of the target host *and the others* — a
   cube-only change must leave durandal, tenacity, lysithea byte-identical.
4. Caddy changes: `caddy adapt` the generated Caddyfile (on darwin, build
   the file from the evaluated config; caught the `handle`-matcher parse
   error once).
5. **Real build on the target host** — a darwin session can't build
   `x86_64-linux` (no remote builder):
   ```sh
   rsync -a --exclude .git ./ nire-cube.local:~/nixos-test/
   ssh -n nire-cube.local 'cd ~/nixos-test && just build'
   ```
   `nire-cube.local`, not `ts-cube` (not in `known_hosts`); `-n` so nothing
   eats the ssh session's stdin.
6. **Read the built artifact.** Unit drop-ins live at
   `$toplevel/etc/systemd/system/<unit>.service.d/overrides.conf` — nixpkgs
   ships some units via `systemd.packages`, so grepping the `.service` alone
   finds nothing and looks like the setting didn't land.
7. **The switch is the human's** — sudo on cube needs a password. Pre-build,
   hand over `just switch`.
8. **Check from another tailnet host.** `curl` the real URL (`%{
   ssl_verify_result}` = 0 behind TLS); `systemctl show <unit> -p
   ActiveState,NRestarts` (`NRestarts=0` — a crash-looper reports `active`
   between restarts); `systemctl list-units --state=failed`; `ss -ltn` for
   the binding.
9. **Check what the service renders, not just the status code.** glance
   serves widgets from `/api/pages/<page>/content/`, so a 200 on `/` proved
   nothing; Forgejo can proxy fine and still emit 404 links. §40's version:
   a failed unit ≠ the thing it manages is down, and vice versa.

Strongest end state, worth stating in the commit when true: the tree being
shipped evaluates to a **byte-identical `outPath`** to what's running.

## 9. Docs, in the same change

Run `wiki-sync`. For a new service: a new `wiki/categories/<category>.md`;
an alphabetical row in `wiki/categories/README.md`'s table; `wiki/hosts.md`;
the URL in `wiki/homelab/README.md`; a paragraph in `AGENTS.md`'s
Architecture section (where the category list lives). If an existing
service's reach changes, its page and module header are stale too.

## 10. Ship

`ship` skill: branch, PR, ask before merging, ask again before deleting.

## See also

- `wiki/lessons-learned.md` §§36, 37, 40, 41 — the runtime-only failures
  this checklist is made of.
- `wiki/categories/reverse-proxy.md` — the routing layer, including the
  prefix asymmetry in full.
- `flake/modules/nire/system/networking/tailscale.nix` — tailnet device
  names ≠ `networking.hostName`; an ACL can block everything with perfect
  config.

---
name: new-homelab-service
description: How to add a self-hosted network service to a host in this repo and verify it actually works.
---

# Adding a homelab service in this repo

## Applies to

Adding a service that listens on a port and is meant to be reached from
another machine — Grafana, Forgejo, golink, glance and Caddy are the five
that exist, all on `nire-cube`. Use it before creating the category, not
after the module is written; several of the decisions below are hard to
undo once a service is live and has state.

Not this skill:

| what you're doing | use instead |
|---|---|
| adding a package to a user's environment | `nirepackages-platform-support` |
| adding a VM guest or building a disk image | `nixos-vm-images` |
| adding a whole host | `new-host-config` |
| the mechanics of one module file | `new-flake-module` |

Those overlap — a service *is* a flake module, so `new-flake-module`'s rules
about filenames, classes and the two `config`s all still apply. This skill is
the layer above: which category, which port, how it's reached, and what
"working" means.

## Why this exists

Five services were added across 2026-08-23 and 2026-08-24 (`monitoring`,
`git-forge`, `shortlinks`, `reverse-proxy`, `landing`). Three of them broke on
their first real switch, each for a reason no amount of re-reading the Nix
would have found:

- `grafana.service` — a secret file owned `root:root` that the service's own
  user couldn't read.
- `golink.service` — a missing `AF_NETLINK` in its own hardening.
- Forgejo behind Caddy — a 404 on every page, because the proxy preserved a
  path prefix the app didn't want.

The pattern is in `claude cave/lessons-learned.md` §§36, 37, 40, 41: each was
invisible to evaluation, to `just modules`, to a real build, and (for the last
one) to reading the built artifact. The checklist below is mostly the accrued
cost of those three.

## The shape

A service is five things, and they land in one commit:

1. a category directory, `flake/modules/nire/<category>/`, with a copy of
   `dirsAsCategory.nix`
2. one module, `<category>/<tool>/<tool>.nix`
3. one line in the host's config (`nireHost/cube-configuration.nix`) with a
   comment saying why
4. a route in `nire/reverse-proxy/caddy/caddy.nix`, if it's HTTP
5. docs — a `wiki/categories/<category>.md` and the indexes that point at it

## 1. Check nixpkgs for a module before writing a unit

Per `CLAUDE.md`'s "check for an existing `programs.*` integration": look for
`services.<tool>` in the pinned nixpkgs before hand-writing anything.

```sh
NP=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./flake)).inputs.nixpkgs.outPath')
ls $NP/nixos/modules/services/*/ | grep -i <tool>
```

Four of the five services here set options on an upstream module. `golink` is
the exception — no `services.golink` exists, so `golink.nix` writes its own
`systemd.services.golink`, and it is the one that failed on a hardening knob.
**A hand-written unit is a much higher-risk change than a module call**; if
you're writing one, expect the first switch to fail and plan the runtime check
accordingly.

## 2. Name the category after the function, never after the tool

A category and a module that share a name both declare
`flake.modules.nixos.<name>` and **silently merge**. This has happened three
times in this tree (`containers`/`podman.nix` for real; `git-forge` and
`shortlinks` caught by `just modules` mid-write).

| category | module | why not the obvious name |
|---|---|---|
| `git-forge` | `forgejo` | `forgejo`/`forgejo` merges |
| `shortlinks` | `golink` | and not `golinks` — one letter off reads as a typo later |
| `reverse-proxy` | `caddy` | `caddy`/`caddy` merges |
| `landing` | `glance` | and not `dashboard` — `monitoring` is full of Grafana dashboards |
| `monitoring` | 5 modules | — |

Run `just modules` immediately after creating the directory. It catches the
collision; nothing else does.

## 3. Pick a port, from the actual registry

There is no allocator. Check what's taken before choosing — a collision is a
bind failure at service start, not an eval error, so nothing catches it until
the switch.

| port | what | binding |
|---|---|---|
| 3000 | Grafana | loopback |
| 3001 | Forgejo | loopback |
| 3002 | glance | loopback |
| 8080 | cadvisor | loopback |
| 9090 | Prometheus | loopback |
| 9100 | node-exporter | loopback |
| 9177 | libvirt-exporter | loopback |
| 2222 | `nire-llm-sandbox` ssh forward | tailnet |
| 80, 443 | Caddy | all interfaces |

Take the next free `300x` for anything user-facing. Grep before trusting this
table — it is a claim about when someone last looked:

```sh
grep -rnE '\b(30[0-9]{2}|80[0-9]{2}|9[0-9]{3})\b' flake/modules/nire/ | grep -iE 'port'
```

**Do not accept a tool's default port without checking it.** glance defaults to
8080, which cadvisor already holds on cube.

## 4. Bind loopback, and add nothing to the firewall

New services bind `127.0.0.1` and are reached through Caddy. Not
`0.0.0.0`-plus-`trustedInterfaces`: that's a firewall property rather than a
listener property, and it's how Grafana and Forgejo were originally written
(both moved on 2026-08-24, see their `history` notes).

`networking.firewall.allowedTCPPorts` gets **no** new entry. The only
tailnet-facing ports on cube are Caddy's 80 and 443.

The exception is a service that isn't on this host's network at all: golink
embeds tsnet and joins the tailnet as its own device, so it has no port here,
no firewall interaction, and no Caddy route.

## 5. The prefix question — get this right before the first switch

MagicDNS gives a device exactly one name, so everything is mounted under a path
prefix on `ts-cube.moose-micro.ts.net`. **Each app must be told its prefix, and
apps disagree about who strips it.** This is lesson §41 and it cost a switch:

- **The app can serve under a subpath** (Grafana's `serve_from_sub_path`) →
  Caddy uses `handle`, prefix left on.
- **The app always serves at `/`** (Forgejo, whatever `ROOT_URL` says) → Caddy
  uses `handle_path`, prefix stripped. Its own base-URL setting then only
  controls the links it *generates*.

Settle it with one command against the running service rather than by reading
docs:

```sh
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<port>/
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<port>/<prefix>/
```

Root 200 and prefix 404 means the app serves at `/` — use `handle_path`.

Two Caddyfile mechanics that bite: `handle` accepts **one** matcher token, so
`handle /a /a/*` is a parse error and two paths need a named matcher
(`@a path /a /a/*`); and `handle_path` accepts an inline path matcher **only**,
so the bare `/a` needs its own `redir` to `/a/`.

A service mounted at `/` — glance — sidesteps all of this, which is the one
place the question doesn't arise.

## 6. Ask whether the upstream module handles its own secrets

`services.forgejo` ships `forgejo-secrets.service` and generates its own
`SECRET_KEY`/`INTERNAL_TOKEN`/`JWT_SECRET` on first activation — nothing to do.
`services.grafana` deliberately doesn't (nixpkgs *removed* its `secretKeyFile`
option), and the hand-created file was found `root:root` and unreadable
**twice**, the second time after a hand fix had supposedly corrected it.

If a secret has to exist on disk, write a oneshot ordered before the service
that **creates it only when missing** and **reasserts ownership and mode every
activation** — `grafana-secret-key-setup.service` in `grafana.nix` is the
worked example. Never regenerate an existing secret: for Grafana's
`secret_key` specifically, overwriting breaks decryption of everything already
in its database.

A `warnings` entry pointing at a manual command is not a fix. That's what was
there before, and the manual step regressed.

## 7. Persistence, which cube doesn't need and other hosts would

`nire-cube` has a plain persistent root, so `/var/lib/<service>` survives
reboots on its own and none of these five modules has a `*-persist.nix`.

`nire-durandal`, `nire-tenacity` and `nire-lego` wipe `/root` on boot. If a
service module is ever imported by one of those, add a persistence entry
**first**, modeled on `tailscale-persist.nix`, and file it next to the module
rather than under `nire/impermanence/` (see `WARN-impermanence.nix` on that
convention). Say so in the module header either way — all five say it.

## 8. Verify, in the order that actually finds things

Each rung finds a class of bug the ones above it cannot. Skipping to the end is
fine; claiming a rung you didn't run is not.

1. `git add` first — flakes ignore untracked files, so a new module silently
   doesn't exist.
2. `just modules` — name collisions and orphans.
3. `nix eval` the host's `toplevel.drvPath`, and the *other* hosts' too. A
   cube-only change must leave durandal, tenacity, lego and lysithea
   byte-identical; that's a two-minute check and it's the repo's standing
   claim.
4. For Caddy changes, `caddy adapt` the generated Caddyfile. On darwin, build
   the file from the evaluated config and run the local `caddy` binary against
   it — this caught the `handle`-matcher parse error before a switch.
5. **A real build on the target host.** A darwin session cannot build an
   `x86_64-linux` toplevel — no remote builder. Sync and build over ssh:
   ```sh
   rsync -a --exclude .git ./ nire-cube.local:~/nixos-caddy-test/
   ssh -n nire-cube.local 'cd ~/nixos-caddy-test && just build'
   ```
   Use `nire-cube.local`, not `ts-cube` — the tailnet name isn't in
   `known_hosts` and ssh refuses it. `-n` matters: a command whose stdin is the
   ssh session will hang if anything reads it.
6. **Read the built artifact.** Unit drop-ins live at
   `$toplevel/etc/systemd/system/<unit>.service.d/overrides.conf`, not in the
   unit file — nixpkgs ships some units via `systemd.packages` and overrides
   them there, so grepping the `.service` alone finds nothing and looks like
   the setting didn't land.
7. **The switch is the human's.** `sudo` on cube needs a password, so an agent
   can build but cannot activate. Pre-build, then hand over `cd
   ~/nixos-caddy-test && just switch`.
8. **Check from another tailnet host, not from the host itself.** `curl` over
   the real URL, and confirm `%{ssl_verify_result}` is 0 for anything behind
   TLS. `systemctl show <unit> -p ActiveState,NRestarts` — `NRestarts=0`
   matters, because a crash-looping unit reports `active` between restarts.
   Plus `systemctl list-units --state=failed` and `ss -ltn` to confirm the
   binding is where you think.
9. **Check what the service actually renders, not just its status code.**
   glance serves its widgets from `/api/pages/<page>/content/`, so a 200 on
   `/` proved nothing about whether the monitors worked. Forgejo can proxy
   correctly and still emit links that 404 on the next click — grep the HTML
   for the prefix. §40's version of this: a failed unit doesn't mean the thing
   it manages is down, and a happy unit doesn't mean it's serving.

The strongest end state, worth stating in the commit when it's true: the tree
being shipped evaluates to a **byte-identical `outPath`** to what's running on
the host.

## 9. Docs, in the same change

Run `wiki-sync`. For a new service that means, at minimum:

- a new `wiki/categories/<category>.md`
- a row in `wiki/categories/README.md`'s table, **alphabetically**, and its
  article count bumped
- `wiki/hosts.md` — what the host now runs and its verification status
- `wiki/homelab/README.md` — the URL, for the humans-using-it tier
- `CLAUDE.md`'s Architecture section — a paragraph, since that's where the
  category list lives

If the service changes how an existing one is reached, that category's page
and module header are stale too — `monitoring` and `git-forge` both needed
rewriting the day Caddy landed.

## 10. Ship

`ship` skill. Branch, PR, ask before merging, ask again before deleting.

## See also

- `claude cave/lessons-learned.md` §§36, 37, 40, 41 — the four runtime-only
  failures this checklist is made of.
- `wiki/categories/reverse-proxy.md` — the routing layer every HTTP service
  here goes through, including the prefix asymmetry in full.
- `wiki/categories/landing.md` — glance, and why its monitor checks go through
  the proxy rather than at loopback.
- `flake/modules/nire/system/networking/tailscale.nix` — the two tailnet traps
  (device names don't match `networking.hostName`; an ACL can block everything
  while the config is perfect).
- `new-flake-module`, `wiki-sync`, `ship` — the three skills this one hands off
  to.

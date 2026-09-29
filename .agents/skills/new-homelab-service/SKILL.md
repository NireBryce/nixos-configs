---
name: new-homelab-service
description: How to add a self-hosted network service to a host in this repo and verify it actually works.
---

# Adding a homelab service in this repo

## Applies to

Adding a service that listens on a port and is reached from another machine
— Grafana, Forgejo, golink, the landing page (homepage since 2026-09-12,
glance before, #291), Caddy; all on `nire-cube`. Use before creating the
category: some decisions are hard to undo once a service has state.

A service is a flake module, so `new-flake-module` still applies; this is the
layer above (category, port, reach, what "working" means). Also
`package-platform-support` (packages), `new-host-config` (hosts; VMs have no
skill, see `wiki/categories/virtualization.md`).

Three of the five services broke on first switch for reasons invisible to
eval, build, and reading the artifact: secret file owner (Grafana), missing
`AF_NETLINK` (golink), unwanted proxy prefix (Forgejo). §§36, 37, 40, 41;
the checklist below is their accrued cost.

## The shape

One commit: category dir `flake/modules/general-config/<category>/` with a
copy of `dirsAsCategory.nix`; module `<category>/<tool>/<tool>.nix`; one
commented line in the host's config; Caddy route if HTTP; docs
(`wiki/categories/<category>.md` + indexes).

## 1. Check nixpkgs for a module before writing a unit

```sh
NP=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./flake)).inputs.nixpkgs.outPath')
ls $NP/nixos/modules/services/*/ | grep -i <tool>
```

Four of five set options on an upstream module. `golink` has none
(`golink.nix` hand-writes its unit) and failed on a hardening knob. A
hand-written unit is high risk: expect the first switch to fail, plan the
runtime check.

A `systemd.user.services` unit declared from NixOS lands in
`/etc/systemd/user` and starts in **every** user's manager, sddm's
included; they race for the port. Gate it with
`unitConfig.ConditionUser` (§45, `opencode-server.nix`).

## 2. Name the category after the function, never the tool

Category and module sharing a name both declare `flake.modules.nixos.<name>`
and **silently merge** (happened with `containers`/`podman.nix`).

| category | module | why not the obvious name |
|---|---|---|
| `git-forge` | `forgejo` | `forgejo`/`forgejo` merges |
| `shortlinks` | `golink` | not `golinks` — one letter off reads as a typo |
| `reverse-proxy` | `caddy` | `caddy`/`caddy` merges |
| `landing` | `homepage` | not `dashboard` — `monitoring` is full of Grafana dashboards (`glance` held the slot until #291) |
| `monitoring` | 5 modules | — |

Run `just modules` right after creating the directory; only it catches this.

## 3. Pick a port from the actual registry

A collision is a bind failure at start, not an eval error.

| port | what | binding |
|---|---|---|
| 3000 | Grafana | loopback |
| 3001 | Forgejo | loopback |
| 3002 | homepage (glance's old slot) | loopback |
| 8080 | cadvisor | loopback |
| 9090 | Prometheus | loopback |
| 9100 | node-exporter | loopback |
| 9177 | libvirt-exporter | loopback |
| 80, 443 | Caddy | all interfaces |

Next free `300x` for user-facing. Grep before trusting the table:

```sh
grep -rnE '\b(30[0-9]{2}|80[0-9]{2}|9[0-9]{3})\b' flake/modules/general-config/ | grep -iE 'port'
```

Never accept a tool's default unchecked: glance defaulted to 8080 (cadvisor's); homepage-dashboard defaults to 8082.

## 4. Bind loopback, add nothing to the firewall

Bind `127.0.0.1`, reach via Caddy — not `0.0.0.0`-plus-`trustedInterfaces`
(a firewall property, not a listener property; how Grafana and Forgejo were
first written). No new `networking.firewall.allowedTCPPorts`: cube's only
tailnet-facing ports are Caddy's 80/443.

Exception: golink embeds tsnet and joins the tailnet as its own device
(`go`): no port, firewall rule, Caddy route, or host `tailscaled`.

## 5. The prefix question — settle before the first switch

MagicDNS gives one name per device, so HTTP services mount under a path
prefix on `ts-cube.moose-micro.ts.net`. Apps disagree on who strips it (§41,
cost a switch):

- Serves under a subpath (Grafana `serve_from_sub_path`) → Caddy `handle`, prefix kept.
- Always serves at `/` (Forgejo, regardless of `ROOT_URL`) → Caddy `handle_path`, prefix stripped; the base-URL setting only affects generated links.

Settle against the running service, not the docs:

```sh
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<port>/
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<port>/<prefix>/
```

Root 200 + prefix 404 → `handle_path`. Caddyfile traps: `handle` takes
**one** matcher token (`handle /a /a/*` is a parse error; use named matcher
`@a path /a /a/*`); `handle_path` takes an inline path matcher only, so a
bare `/a` needs its own `redir` to `/a/`. A service at `/` (landing page)
avoids all this. Own `svc:` hostname instead of a prefix: `new-tailscale-service`.

## 6. Does the upstream module handle its own secrets?

`services.forgejo` generates its own on first activation. `services.grafana`
doesn't (nixpkgs removed `secretKeyFile`); the hand-created file was found
unreadable twice. If a secret must exist on disk: a oneshot ordered before
the service that creates it only when missing and reasserts owner/mode every
activation — `grafana-secret-key-setup.service` in `grafana.nix` is the
example. Never regenerate an existing secret (Grafana's `secret_key`
overwrite breaks decryption of its whole database). A `warnings` entry
naming a manual command is not a fix (regressed before).

## 7. Persistence

`nire-cube` has a plain persistent root: `/var/lib/<service>` survives, no
module has a `*-persist.nix`. If a `/root`-wiping host (durandal, tenacity)
imports a service module, add a persistence entry **first**, modeled on
`tailscale-persist.nix`, filed next to the module (not under
`general-config/impermanence/`; see `WARN-impermanence.nix`). Each module
header states which case applies; keep that.

## 8. Verify, in the order that finds things

Skipping rungs is fine; claiming one you didn't run is not.

1. `git add` first (untracked modules don't exist to flakes).
2. `just modules` — collisions and orphans.
3. `nix eval` toplevel drvPath of the target host *and the others* — a cube-only change must leave durandal, tenacity, lysithea byte-identical.
4. Caddy: `caddy adapt` the generated Caddyfile (on darwin, build the file from the evaluated config; caught the `handle` parse error once).
5. **Real build on the target host** (darwin can't build `x86_64-linux`, no remote builder):
   ```sh
   rsync -a --exclude .git ./ nire-cube.local:~/nixos-test/
   ssh -n nire-cube.local 'cd ~/nixos-test && just build'
   ```
   `nire-cube.local`, not `ts-cube` (not in `known_hosts`); `-n` so nothing eats ssh's stdin.

   Eval, build and reading the artifact all miss state a daemon holds: a secret file's owner set outside Nix, libvirt's defined-vs-started network. Only the switch shows it, via `systemctl status` and `journalctl -u` right after (§37).
6. **Read the built artifact.** Drop-ins: `$toplevel/etc/systemd/system/<unit>.service.d/overrides.conf` — nixpkgs ships some units via `systemd.packages`, so grepping the `.service` alone finds nothing and looks like the setting didn't land.
7. **The switch is the human's** (sudo on cube needs a password). Pre-build, hand over `just switch`.
8. **Check from another tailnet host.** `curl` the real URL (`%{ssl_verify_result}` = 0 behind TLS); `systemctl show <unit> -p ActiveState,NRestarts` (`NRestarts=0`; a crash-looper reports `active` between restarts); `systemctl list-units --state=failed`; `ss -ltn` for the binding. When two components can claim one port, `ss -ltnp` names who holds it; "enabled" doesn't (§46).
9. **Check what the service renders, not the status code.** glance served widgets from `/api/pages/<page>/content/`, so 200 on `/` proved nothing (homepage is client-side — check the rendered page and widgets in a browser); Forgejo can proxy fine and still emit 404 links. §40: a failed unit ≠ the managed thing is down, and vice versa.

Strongest end state, worth stating in the commit: the shipped tree evaluates
to a **byte-identical `outPath`** to what's running.

## 9. Docs, in the same change

Run `wiki-sync`. New service: new `wiki/categories/<category>.md` (skill
`new-wiki-page`); alphabetical row in `wiki/categories/00-INDEX.md`;
`wiki/hosts.md`; URL in `wiki/homelab/00-INDEX.md`; `AGENTS.md` has no per-category list (only the homelab umbrella note; touch it only if that changes).
A changed reach makes the service's page and module header stale too.

Long pages touched here have a `-for-agents.md` sibling (the half an agent
loads; `wiki/styleguide.md` "Two audiences per page"); `wiki-sync` step 5
covers it and `just wiki-lint` fails a date bump without it. A new category
page needs one only past 1,000 words.

## 10. Ship

`ship` skill.

## See also

- `wiki/lessons-learned.md` §§36, 37, 40, 41.
- `wiki/categories/reverse-proxy.md` — routing layer, prefix asymmetry in full.
- `flake/modules/general-config/system/networking/tailscale.nix` — tailnet device names ≠ `networking.hostName`; an ACL can block everything with perfect config.

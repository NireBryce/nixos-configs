---
name: new-homelab-service
description: Adds a self-hosted network service to a host and verifies it works after the first switch.
when_to_use: Adding a service that listens on a port and is reached from another machine, before creating its category.
---

# Adding a homelab service in this repo

**Needs:** bash-guards

## Applies to

Use when adding a service that listens on a port and is reached from another machine (Grafana, Forgejo, golink, Caddy; all on `nire-cube`). Use it before creating the category, because some decisions are hard to undo once a service has state.

A service is a flake module, so `new-flake-module` still applies. This skill is the layer above it: category, port, reach, and what "working" means. See also `package-platform-support` (packages) and `new-host-config` (hosts; VMs have no skill, see `wiki/config-structure/categories/virtualization.md`).

Three of the five services broke on first switch for reasons that eval, build, and reading the artifact could not show: secret file owner (Grafana), missing `AF_NETLINK` (golink), unwanted proxy prefix (Forgejo). See §§36, 37, 40, 41. The checklist below records what those failures cost.

## The shape

One commit contains:

- the category dir `flake/modules/homelab-config/homelab/<category>/` (a category because `<tool>/` holds the module);
- the module `<category>/<tool>/<tool>.nix`;
- one commented line in the host's config;
- a Caddy route, if the service speaks HTTP;
- docs (`wiki/config-structure/categories/<category>.md` and the indexes).

## 1. Check nixpkgs for a module before writing a unit

```sh
NP=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./flake)).inputs.nixpkgs.outPath')
ls $NP/nixos/modules/services/*/ | grep -i <tool>
```

Four of the five services set options on an upstream module. `golink` has none (`golink.nix` hand-writes its unit) and failed on a hardening option. A hand-written unit is likely to fail its first switch, so plan the runtime check.

A `systemd.user.services` unit declared from NixOS lands in `/etc/systemd/user` and starts in **every** user's manager, sddm's included, and the managers race for the port. Gate it with `unitConfig.ConditionUser` (§45).

## 2. Name the category after the function, never the tool

A category and a module with the same name share one name. A repeated name now stops evaluation (dirs-as-categories refuses it), but it once merged silently, which is how `containers`/`podman.nix` happened.

| category | module | why not the obvious name |
|---|---|---|
| `git-forge` | `forgejo` | `forgejo`/`forgejo` merges |
| `shortlinks` | `golink` | not `golinks`; one letter off reads as a typo |
| `reverse-proxy` | `caddy` | `caddy`/`caddy` merges |
| `monitoring` | the modules under `monitoring/` | none |

Run `just modules` right after creating the directory; only it catches this.

## 3. Pick a port from the actual registry

A port collision is a bind failure at start, not an eval error.

| port | what | binding |
|---|---|---|
| 3000 | Grafana | loopback |
| 3001 | Forgejo | loopback |
| 8080 | cadvisor | loopback |
| 9090 | Prometheus | loopback |
| 9100 | node-exporter | loopback |
| 9177 | libvirt-exporter | loopback |
| 9633 | smartctl-exporter | loopback |
| 80, 443 | Caddy | all interfaces |

Use the next free `300x` for user-facing services. Grep before trusting the table:

```sh
grep -rnE '\b(30[0-9]{2}|80[0-9]{2}|9[0-9]{3})\b' flake/modules/general-config/ | grep -iE 'port'
```

Check a tool's default port before accepting it: glance defaulted to 8080 (cadvisor's) and homepage-dashboard to 8082 (both since removed).

## 4. Bind loopback, add nothing to the firewall

Bind `127.0.0.1` and reach the service through Caddy. Do not bind `0.0.0.0` and rely on `trustedInterfaces`, which is a firewall property, not a listener property (Grafana and Forgejo were first written that way). Add no `networking.firewall.allowedTCPPorts`: cube's only tailnet-facing ports are Caddy's 80/443.

Exception: golink embeds tsnet and joins the tailnet as its own device (`go`). It needs no port, firewall rule, Caddy route, or host `tailscaled`.

## 5. The prefix question — settle before the first switch

MagicDNS gives one name per device, so HTTP services mount under a path prefix on `ts-cube.moose-micro.ts.net`. Apps differ on who strips the prefix (§41; getting it wrong cost a switch):

- The app serves under a subpath (Grafana `serve_from_sub_path`): use Caddy `handle`, which keeps the prefix.
- The app always serves at `/` (Forgejo, regardless of `ROOT_URL`): use Caddy `handle_path`, which strips the prefix. The base-URL setting only affects generated links.

Test against the running service, not the docs:

```sh
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<port>/
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<port>/<prefix>/
```

Root 200 and prefix 404 means use `handle_path`. Caddyfile traps:

- `handle` takes **one** matcher token. `handle /a /a/*` is a parse error; use the named matcher `@a path /a /a/*`.
- `handle_path` takes an inline path matcher only, so a bare `/a` needs its own `redir` to `/a/`.

A service mounted at `/` avoids all of this. To give a service its own `svc:` hostname instead of a prefix, see `new-tailscale-service`.

## 6. Does the upstream module handle its own secrets?

`services.forgejo` generates its own on first activation. `services.grafana` does not (nixpkgs removed `secretKeyFile`), and the hand-created file was unreadable twice. If a secret must exist on disk, use a oneshot unit ordered before the service. It creates the file only when missing and reasserts owner and mode on every activation; `grafana-secret-key-setup.service` in `grafana.nix` is the example.

Never regenerate an existing secret: overwriting Grafana's `secret_key` breaks decryption of its whole database. A `warnings` entry naming a manual command is not a fix (it regressed before).

## 7. Persistence

`nire-cube` has a plain persistent root, so `/var/lib/<service>` survives and no module has a `*-persist.nix`. If a `/root`-wiping host (durandal, tenacity) imports a service module, add a persistence entry **first**, modeled on `tailscale-persist.nix` and filed next to the module (not under `general-config/impermanence/`; see `WARN-impermanence.nix`). Each module header states which case applies; keep that.

## 8. Verify, in the order that finds things

Skipping rungs is fine; claiming one you did not run is not.

1. `git add` first. Flakes ignore untracked modules.
2. `just modules` (orphans, meaning a module nothing reaches; untracked files; drift) and `just check`. A repeated name fails evaluation itself.
3. `nix eval` the toplevel drvPath of the target host *and the others*. A cube-only change must leave durandal, tenacity and lysithea byte-identical.
4. Caddy: run `caddy adapt` on the generated Caddyfile. On darwin, build the file from the evaluated config. This caught the `handle` parse error once.
5. **Build on the target host.** Darwin cannot build `x86_64-linux` and there is no remote builder:
   ```sh
   rsync -a --exclude .git ./ nire-cube.local:~/nixos-test/
   ssh -n nire-cube.local 'cd ~/nixos-test && just build'
   ```
   Use `nire-cube.local`, not `ts-cube` (not in `known_hosts`), and `-n` so nothing eats ssh's stdin.

   Eval, build and reading the artifact all miss state a daemon holds: a secret file's owner set outside Nix, libvirt's defined-vs-started network. Only the switch shows it, through `systemctl status` and `journalctl -u` right after (§37).
6. **Read the built artifact.** Check drop-ins at `$toplevel/etc/systemd/system/<unit>.service.d/overrides.conf`. nixpkgs ships some units via `systemd.packages`, so grepping the `.service` file alone finds nothing and looks as if the setting did not land.
7. **Hand the switch to the user.** Sudo on cube needs a password. After the build, give them `just switch`.
8. **Check from another tailnet host:**
   - `curl` the real URL (`%{ssl_verify_result}` is 0 behind TLS).
   - `systemctl show <unit> -p ActiveState,NRestarts` should show `NRestarts=0`; a crash-looping unit reports `active` between restarts.
   - `systemctl list-units --state=failed`.
   - `ss -ltn` for the binding. When two components can claim one port, `ss -ltnp` names the holder; "enabled" does not (§46).
9. **Check what the service renders, not the status code.** glance served widgets from `/api/pages/<page>/content/`, so a 200 on `/` proved nothing. homepage is client-side, so check the rendered page and widgets in a browser. Forgejo can proxy correctly and still emit 404 links. See §40: a failed unit does not mean the managed thing is down, and the reverse.

The best end state, worth stating in the commit: the shipped tree evaluates to a **byte-identical `outPath`** to what is running.

## 9. Docs, in the same change

Run `wiki-sync`. For a new service:

- add `wiki/config-structure/categories/<category>.md` (skill `new-wiki-page`);
- add an alphabetical row in `wiki/config-structure/categories/00-INDEX.md`;
- update `wiki/fleet/hosts.md`;
- add the URL in `wiki/homelab/00-INDEX.md`;
- leave `AGENTS.md` alone unless the homelab umbrella note changes; it has no per-category list.

A changed reach makes the service's page and module header stale too.

Long pages touched here have a `-for-agents.md` sibling, the half an agent loads (`wiki/meta/styleguide.md` "Two audiences per page"). `wiki-sync` step 5 covers it, and `just wiki-lint` fails a date bump without it. A new category page needs a sibling only past 1,000 words.

## 10. Ship

Use the `ship` skill.

## See also

- `wiki/agent-lessons-learned.md` §§36, 37, 40, 41.
- `wiki/config-structure/categories/reverse-proxy.md`: routing layer, prefix asymmetry in full.
- `flake/modules/general-config/system/networking/tailscale.nix`: tailnet device names differ from `networking.hostName`, and an ACL can block everything with perfect config.

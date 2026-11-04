---
name: new-tailscale-service
description: Gives a homelab service its own Tailscale Services hostname, with Caddy terminating TLS.
when_to_use: A running homelab service should be reachable at its own tailnet hostname instead of a path under the host's shared name.
---

# Giving a homelab service its own Tailscale Services hostname

## Applies to

Use when a service already runs on `nire-cube` (or another homelab host) and is reachable only through a Caddy path prefix under the host's shared `ts-<host>` name (`new-homelab-service`'s default). This skill gives it `https://<name>.<tailnet-domain>/`. It assumes the app is built, switched, and bound to a loopback port; writing the service module is `new-homelab-service`.

This is not Funnel: Tailscale Services stay tailnet-only. It does not replace Caddy either. As of the 2026-09-07 check (Background below; re-check on a newer nixpkgs), `services.tailscale.serve` cannot terminate HTTPS declaratively (step 6), so Caddy terminates TLS per service name instead of per path.

## Background (2026-09-07)

Grafana and Forgejo moved from `ts-cube.../grafana/` and `.../git/` to `grafana.<tailnet-domain>` and `git.<tailnet-domain>` the day `svc:` opened on this tailnet. They are the worked examples. The account is in `wiki/config-structure/categories/reverse-proxy.md` and `flake/modules/homelab-config/homelab/reverse-proxy/tailscale-services/`. Read the history section of `serve.nix` for the failed first design, which is the one most likely to be re-invented.

## The shape

Three resources, two of them outside this repo's Nix:

| resource | where | changed by |
|---|---|---|
| tailnet ACL/policy (tag, grant, `autoApprovers.services`) | Tailscale control plane | `just tailscale-acl diff/apply` on a local HuJSON file |
| `svc:` Service object (name/tags/ports) | control plane, separate API resource | `just tailscale-acl vip-put <name> <file>` |
| `services.tailscale.serve` (raw TCP forward) + Caddy vhost | this repo | normal Nix commit |

## Steps

1. **Confirm the app is loopback-only behind Caddy.** If it is not, do `new-homelab-service` first.

2. **Tag the host and add the compensating grant in the same change.** A tagged device is owned by the tag and drops out of `autogroup:members` as a grant *destination*. On 2026-09-07, `nire-cube` vanished from peers' `tailscale status` within about 1 minute of tagging. Add:
   ```json
   {"src": ["autogroup:members"], "dst": ["tag:<host-tag>"], "ip": ["*"]}
   ```
   Tag the host with `sudo tailscale up --advertise-tags=tag:<host-tag>` (`tailscale set` has no `--advertise-tags` on this version). Skip this step if the host is already tagged.

3. **Add `autoApprovers.services` for the tag**, so advertising a `svc:` needs no manual admin-console click.

4. **Apply the ACL as a diff; never edit it live.** Edit a local HuJSON file under `tailscale-services/` (shape: `acl-diff-applied.hujson`), then run:
   ```sh
   just tailscale-acl diff <file>
   just tailscale-acl apply <file>
   ```
   `apply` refuses an empty diff and asks for confirmation before POSTing. It needs `tailscale_api_token` in `secrets.yaml` (the script header says how to add it). A committed HuJSON records intent, not what the control plane holds: `acl-diff-applied.hujson` once recorded an autoApprover that was never POSTed (§48). The step is done when `just tailscale-acl diff` reports no difference.

5. **Create the Service object.** Put a JSON file (name/tags/ports/comment) beside the ACL file, then run `just tailscale-acl vip-put <name> <file>`. The endpoint is `/api/v2/tailnet/{tailnet}/vip-services/{name}`, **not** `/vip-services/by-name/{name}`, which returns a bare routing 404 rather than a "not found" JSON body. Do not put a top-level `"services"` key in the *ACL* file: it belongs to the per-node serve config, and the policy endpoint rejects it (`unknown field "services"`).

6. **Add the service to the table** in `homelab/_lib/cube-services.nix`: `<name>.port = <app-port>;`. This one entry is the source for everything below: the app reads its `port`/`url`/`fqdn` from it, `serve.nix` forwards a pair for it, and `caddy.nix`'s `mkTsService` builds its vhosts. The old shape was a hand-copied `services.tailscale.serve.services.<name>` block plus a vhost trio, with the port and FQDN repeated in the app module.

   `serve.nix` generates, per entry, `endpoints."tcp:443" = "tcp://127.0.0.1:443";` and `endpoints."tcp:80" = "tcp://127.0.0.1:80";`. List both ports in the Service object's `ports` and re-run `vip-put` after editing; 443 alone left the bare-name `http://` redirects unreachable (#272).

   The scheme is `tcp://`, **not** `http://`, and the target is **Caddy's loopback listener**, not the app port. The upstream option-doc form `"http://127.0.0.1:<app-port>"` gives no real HTTPS, because `serve set-config`/`get-config` rounds an endpoint's scheme down to `http://` on this version (tailscale/tailscale#18381; the raw-CLI workaround in #18219 does not survive `set-config` or reboot). With `tcp://`, tailscaled forwards untouched TLS bytes (SNI included) to 443 and Caddy terminates. `services.<name>` becomes `svc:<name>`; the module adds the prefix, so do not.

7. **Choose a guard** for the service in `caddy.nix`'s `guards`: `vmDeny`, unless guests need something specific. `mkTsService` then emits the `<name>.<tailnet-domain>` TLS vhost (`reverse_proxy 127.0.0.1:<port>`, no path matcher) and both bare-name redirects; read it as the reference. A table entry with no `guards` line fails evaluation by design. The cert mechanism is the same `isTailscaleDomain` one as the host vhost: Caddy asks tailscaled for a cert by **site address**, not by the connecting socket, so a loopback arrival is fine.

8. **Point the app at its table entry**: `port = <name>.port` and `root_url`/`ROOT_URL = <name>.url`, as `grafana.nix` and `forgejo.nix` do (`(import ../../_lib/cube-services.nix).services.<name>`). Drop path-prefix settings (`serve_from_sub_path`-style). A leftover prefix causes the generated-link mismatch that `new-homelab-service` step 5 warns about, in reverse.

## Verify

Run `new-homelab-service`'s ladder (eval, `just modules`, `caddy adapt`, real build on the target host), plus:

- From another tailnet host, run `curl -sso /dev/null -w '%{http_code} %{ssl_verify_result}\n' https://<name>.<tailnet-domain>/`. Expect `200 0` (or the app's real root status) with a **validated** cert.
- The old path-prefixed URL now returns 404.
- The backend port is still loopback-only (`ss -ltn` on the host).
- `tailscale serve status` shows `http://<name>...:443`, not `https://`. That is the #18381 display bug and does not mean HTTPS is off; trust `curl`.
- App-generated links use the new hostname. A Forgejo `ROOT_URL` mismatch cost a switch once (`wiki/agent-lessons-learned.md` #41).

## Docs

Run `wiki-sync`, including step 5: three pages below have `-for-agents.md` siblings with the same URL map and traps, and `just wiki-lint` fails if a date moves without its sibling. Likely stale: `wiki/config-structure/categories/reverse-proxy.md`, `tailscale-services/README.md`, the URL map in `wiki/homelab/reaching-services.md`, and any open issue this closes (`gh issue list --search "Tailscale Services"`).

## See also

- `new-homelab-service`: do it first if the service is not already behind Caddy.
- `flake/modules/homelab-config/homelab/_lib/cube-services.nix`: the table; `caddy.nix`'s `mkTsService` is the vhost reference.
- `flake/modules/homelab-config/homelab/reverse-proxy/tailscale-services/serve.nix`: failed first design in its history section.
- `.../tailscale-services/README.md`: ACL/tag/service-object side, tagging incident in full.
- `wiki/config-structure/categories/reverse-proxy.md`: Caddy's half, cert mechanism, why `permitCertUid` is scoped where it is.
- `flake/scripts/tailscale-acl.py`: header has endpoint-naming traps (`/acl` not `/policy`, `/vip-services/{name}` not `/by-name/{name}`).

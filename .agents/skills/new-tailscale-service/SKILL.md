---
name: new-tailscale-service
description: How to give a homelab service its own Tailscale Services hostname fronted by Caddy for TLS.
---

# Giving a homelab service its own Tailscale Services hostname

## Applies to

A service already running on `nire-cube` (or another homelab host), reachable only via a Caddy path prefix under the host's shared `ts-<host>` name (`new-homelab-service`'s default); this gives it `https://<name>.<tailnet-domain>/`. Assumes the app is built, switched, on a loopback port; writing the service module is `new-homelab-service`.

Not Funnel (Tailscale Services stay tailnet-only). Not a Caddy replacement: as of tailscale 1.102.2 `services.tailscale.serve` cannot terminate HTTPS declaratively (step 6), so Caddy does TLS per service name instead of per path.

## Background (2026-09-07)

Grafana and Forgejo moved from `ts-cube.../grafana/` and `.../git/` to `grafana.<tailnet-domain>`/`git.<tailnet-domain>` the day `svc:` opened on this tailnet. Worked example; account in `wiki/categories/reverse-proxy.md` and `flake/modules/general-config/homelab/reverse-proxy/tailscale-services/`. Read `serve.nix`'s history section for the failed first design (most likely to be re-invented).

## The shape

Three resources, two outside this repo's Nix:

| resource | where | changed by |
|---|---|---|
| tailnet ACL/policy (tag, grant, `autoApprovers.services`) | Tailscale control plane | `just tailscale-acl diff/apply` on a local HuJSON file |
| `svc:` Service object (name/tags/ports) | control plane, separate API resource | `just tailscale-acl vip-put <name> <file>` |
| `services.tailscale.serve` (raw TCP forward) + Caddy vhost | this repo | normal Nix commit |

## Steps

1. **Confirm the app is loopback-only behind Caddy**; if not, that's `new-homelab-service`.

2. **Tag the host and add the compensating grant in the same change.** A tagged device is owned by the tag and drops out of `autogroup:members` as a grant *destination*: live 2026-09-07, `nire-cube` vanished from peers' `tailscale status` within ~1 minute of tagging. Add:
   ```json
   {"src": ["autogroup:members"], "dst": ["tag:<host-tag>"], "ip": ["*"]}
   ```
   Tag on the host: `sudo tailscale up --advertise-tags=tag:<host-tag>` (`tailscale set` has no `--advertise-tags` on this version). Skip if already tagged.

3. **Add `autoApprovers.services` for the tag**, so advertising a `svc:` needs no manual admin-console click.

4. **Apply the ACL as a diff, never hand-edited live**: edit a local HuJSON under `tailscale-services/` (shape: `acl-diff-applied.hujson`), then
   ```sh
   just tailscale-acl diff <file>
   just tailscale-acl apply <file>
   ```
   `apply` refuses an empty diff and confirms before POSTing. Needs `tailscale_api_token` in `secrets.yaml` (script header says how to add it).

5. **Create the Service object**: JSON (name/tags/ports/comment) beside the ACL file, then `just tailscale-acl vip-put <name> <file>`. Endpoint is `/api/v2/tailnet/{tailnet}/vip-services/{name}`, **not** `/vip-services/by-name/{name}` (404s with a bare routing miss, not a "not found" JSON body). Don't put a top-level `"services"` key in the *ACL* file — it belongs to the per-node serve config; the policy endpoint rejects it (`unknown field "services"`).

6. **Add the raw TCP forward** in `tailscale-services/serve.nix`:
   ```nix
   services.tailscale.serve.services.<name>.endpoints."tcp:443" = "tcp://127.0.0.1:443";
   ```
   `tcp://`, **not** `http://`; target is **Caddy's loopback listener**, not the app port. The upstream option-doc form `"http://127.0.0.1:<app-port>"` gives no real HTTPS: `serve set-config`/`get-config` rounds an endpoint's scheme down to `http://` on this version (tailscale/tailscale#18381; the raw-CLI workaround in #18219 doesn't survive `set-config` or reboot). tailscaled forwards untouched TLS bytes (SNI included) to 443; Caddy terminates. `services.<name>` becomes `svc:<name>` (module adds the prefix; don't).

7. **Add a Caddy vhost for `<name>.<tailnet-domain>`** in `caddy.nix`: plain `reverse_proxy 127.0.0.1:<app-port>`, no path matcher (`handle`/`handle_path` not needed). Same `isTailscaleDomain` cert mechanism as the host vhost: Caddy asks tailscaled for a cert by **site address**, not the connecting socket, so loopback arrival is fine.

8. **Point the app at its bare hostname**, dropping path-prefix settings (`serve_from_sub_path`/`root_url`/`ROOT_URL`-style). A leftover prefix causes the generated-link mismatch `new-homelab-service` step 5 warns about, inverted.

## Verify

`new-homelab-service`'s ladder (eval, `just modules`, `caddy adapt`, real build on target host), plus:

- From another tailnet host: `curl -sso /dev/null -w '%{http_code} %{ssl_verify_result}\n' https://<name>.<tailnet-domain>/` — expect `200 0` (or the app's real root status) with a **validated** cert.
- Old path-prefixed URL now 404s.
- Backend port still loopback-only (`ss -ltn` on host).
- `tailscale serve status` shows `http://<name>...:443`, not `https://` — the #18381 display bug, not evidence HTTPS is off. Trust `curl`.
- App-generated links use the new hostname (Forgejo `ROOT_URL` mismatch cost a switch once, `wiki/lessons-learned.md` #41).

## Docs

Run `wiki-sync` incl. step 5 (three pages below have `-for-agents.md` siblings with the same URL map and traps; `just wiki-lint` fails if a date moves without its sibling). Likely stale: `wiki/categories/reverse-proxy.md`, `tailscale-services/README.md`, `wiki/homelab/reaching-services.md` URL map, `wiki/open-threads.md` Tailscale Services entry if this closes an open item.

## See also

- `new-homelab-service` — do first if the service isn't already behind Caddy.
- `flake/modules/general-config/homelab/reverse-proxy/tailscale-services/serve.nix` — worked example + failed first design.
- `.../tailscale-services/README.md` — ACL/tag/service-object side, tagging incident in full.
- `wiki/categories/reverse-proxy.md` — Caddy's half, cert mechanism, why `permitCertUid` is scoped where it is.
- `flake/scripts/tailscale-acl.py` — header has endpoint-naming traps (`/acl` not `/policy`, `/vip-services/{name}` not `/by-name/{name}`).

---
name: new-tailscale-service
description: How to give a homelab service its own Tailscale Services (svc:) hostname, fronted by Caddy for TLS, instead of a Caddy path prefix under the host's shared name.
---

# Giving a homelab service its own Tailscale Services hostname

## Applies to

A service already running on `nire-cube` (or another homelab host), reachable
today only via a Caddy path prefix under the host's shared `ts-<host>` name
(`new-homelab-service`'s default). This skill is the step that gives it a
name of its own — `https://<name>.<tailnet-domain>/` — instead. It assumes
the app is already built, switched, and sitting on a loopback port; it does
not cover writing the service module itself (`new-homelab-service` does).

Not Funnel — Tailscale Services stay tailnet-only, same reach as everything
else on this front door. Not a replacement for Caddy: as of tailscale
1.102.2, `services.tailscale.serve` cannot terminate HTTPS declaratively
(see below), so Caddy still does the TLS work, just per-service-name instead
of per-path.

## Why this exists (2026-09-07)

Grafana and Forgejo moved off `ts-cube.../grafana/` and `ts-cube.../git/`
onto `grafana.<tailnet-domain>`/`git.<tailnet-domain>` the same day
Tailscale Services (`svc:`) opened up on this tailnet — full account in
`wiki/categories/reverse-proxy.md` and
`flake/modules/nire/homelab/reverse-proxy/tailscale-services/`. That move is
the worked example this skill generalizes; read `serve.nix`'s history
section once for the failed first design, since it's the trap most likely to
be re-invented.

## The shape

Three resources, two of them **outside this repo's Nix**, one commit for the
in-repo part:

| resource | where it lives | how it's changed |
|---|---|---|
| tailnet ACL/policy (tag, grant, `autoApprovers.services`) | Tailscale's control plane | `just tailscale-acl diff/apply` against a local HuJSON file |
| the `svc:` Service object (name/tags/ports) | Tailscale's control plane, a separate API resource from the policy | `just tailscale-acl vip-put <name> <file>` |
| `services.tailscale.serve` (raw TCP forward) + the Caddy vhost | this repo | a normal Nix commit |

## Steps

1. **Confirm the app is already loopback-only behind Caddy.** If it isn't,
   that's `new-homelab-service`, not this skill.

2. **Tag the host, and add the compensating grant in the same change.** A
   tagged device is owned by the tag for ACL purposes and drops out of
   `autogroup:members` as a grant *destination* — happened live 2026-09-07,
   `nire-cube` vanished from every peer's `tailscale status` within about a
   minute of tagging. Fix is one more grant, same change:
   ```json
   {"src": ["autogroup:members"], "dst": ["tag:<host-tag>"], "ip": ["*"]}
   ```
   Tag the host itself with `sudo tailscale up --advertise-tags=tag:<host-tag>`
   on the host — `tailscale set` has no `--advertise-tags` flag on this
   tailscale version. Skip this step if the host is already tagged from a
   prior service.

3. **Add `autoApprovers.services` for the tag**, so advertising a `svc:`
   under it doesn't need a manual per-service admin-console click — the cost
   `wiki/open-threads.md`'s Tailscale Services entry originally cited, and
   the reason this mechanism was worth revisiting.

4. **Review and apply the ACL as a diff, never hand-edited live**: edit a
   local HuJSON file under `tailscale-services/` (see
   `acl-diff-applied.hujson` for the shape), then
   ```sh
   just tailscale-acl diff <file>
   just tailscale-acl apply <file>
   ```
   `apply` refuses an empty diff and confirms before POSTing. The API needs
   `tailscale_api_token` in `secrets.yaml` — the script's own header says how
   to add it if missing.

5. **Create the Service object**, a JSON file (name/tags/ports/comment) next
   to the ACL file, then `just tailscale-acl vip-put <name> <file>`. Hits
   `/api/v2/tailnet/{tailnet}/vip-services/{name}` — **not**
   `/vip-services/by-name/{name}`, which 404s with a bare routing miss
   rather than a real "service not found" JSON body. Don't put a top-level
   `"services"` key in the *ACL* file to do this — that key belongs to the
   per-node serve config (next step), and the policy endpoint rejects it
   outright with `unknown field "services"`.

6. **Add the raw TCP forward** in `tailscale-services/serve.nix`:
   ```nix
   services.tailscale.serve.services.<name>.endpoints."tcp:443" = "tcp://127.0.0.1:443";
   ```
   `tcp://`, **not** `http://`, and the target is **Caddy's own loopback
   listener**, not the app's port directly. The obvious-looking
   `"http://127.0.0.1:<app-port>"` — the form the upstream module's own
   option doc example uses — does not give you real HTTPS: `serve
   set-config`/`get-config` always rounds an endpoint's scheme down to
   `http://` on this tailscale version (confirmed upstream bug
   tailscale/tailscale#18381; the raw-CLI-only workaround in #18219 doesn't
   survive `set-config` or a reboot either). tailscaled forwards the
   untouched TLS bytes, SNI included, to whatever's on 443; Caddy is what
   actually terminates it. `services` here becomes `svc:<name>` — the
   module adds the prefix, don't add it yourself in the key.

7. **Add a Caddy vhost for `<name>.<tailnet-domain>`** in `caddy.nix`, a
   plain `reverse_proxy 127.0.0.1:<app-port>` — no path matcher, the app
   owns the whole vhost now, so `handle`/`handle_path` don't come up. Same
   `isTailscaleDomain` cert mechanism as the host's own vhost: Caddy asks
   tailscaled for a cert using the **site address**
   (`<name>.<tailnet-domain>`), not the connecting socket's address, so it
   doesn't matter that the connection arrives over loopback.

8. **Point the app at its new bare hostname**, dropping the path-prefix
   settings it needed before (`serve_from_sub_path`/`root_url`-style options,
   `ROOT_URL`-style options) — it now serves at `/`, not under a shared
   prefix. Leaving the old prefix setting in place after the vhost stops
   using a prefix produces exactly the kind of generated-link mismatch
   `new-homelab-service` step 5 warns about, just inverted.

## Verify

Same discipline as `new-homelab-service`'s ladder — eval, `just modules`,
`caddy adapt`, real build on the target host — plus what only a live request
shows:

- `curl -sso /dev/null -w '%{http_code} %{ssl_verify_result}\n'
  https://<name>.<tailnet-domain>/` from another tailnet host — expect `200
  0` (or whatever the app's real root status is) with a **validated** cert,
  not just present.
- The old path-prefixed URL now 404s.
- The backend port is still loopback-only (`ss -ltn` on the host).
- `tailscale serve status` will show `http://<name>...:443`, not `https://`
  — that's the known display/round-trip bug (#18381), not evidence HTTPS
  isn't actually happening. Trust the `curl` result, not this output.
- The app's own generated links use the new hostname, not a stale prefixed
  one (Forgejo's `ROOT_URL` mismatch cost a switch here once already, per
  `wiki/lessons-learned.md` #41 — same class of bug, new setting).

## Docs

Run `wiki-sync`. Likely stale after this: `wiki/categories/reverse-proxy.md`,
`tailscale-services/README.md`, `wiki/homelab/reaching-services.md`'s URL
map, and `wiki/open-threads.md`'s Tailscale Services entry if this closes
what it lists as still open.

## See also

- `new-homelab-service` — the broader checklist this extends; do that one
  first if the service isn't already running behind Caddy.
- `flake/modules/nire/homelab/reverse-proxy/tailscale-services/serve.nix` —
  the worked example, including the failed first design in its history
  section.
- `flake/modules/nire/homelab/reverse-proxy/tailscale-services/README.md` —
  the ACL/tag/service-object side, and the tagging incident in full.
- `wiki/categories/reverse-proxy.md` — Caddy's half of this, including the
  cert mechanism and why `permitCertUid` is scoped where it is.
- `flake/scripts/tailscale-acl.py` — the ACL/vip-services script; its own
  header has the endpoint-naming traps (`/acl` not `/policy`,
  `/vip-services/{name}` not `/vip-services/by-name/{name}`).

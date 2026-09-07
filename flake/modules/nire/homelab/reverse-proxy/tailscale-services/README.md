# Tailscale Services state, applied 2026-09-07

Not read by anything -- Nix, sops, or otherwise. These are records of what
was actually applied to the live tailnet via `flake/scripts/tailscale-acl.py`
(itself run through `just tailscale-acl`), kept here so a future change has
something to diff against instead of re-fetching the live state cold.
Editing a file in this directory does **not** change anything live; re-run
the script (`vip-put`/`apply`) to push an edit.

- `acl-diff-applied.hujson` -- the tailnet policy file as POSTed. Adds
  `tag:homelab-cube`, `autoApprovers.services` for `svc:grafana`/`svc:git`
  (pre-approving that tag to advertise both, removing the manual
  per-service console click wiki/open-threads.md's Tailscale Services
  entry cited as a cost), and explicit grants for the two service
  destinations.
- `svc-grafana.json`, `svc-git.json` -- the two Tailscale Service objects
  (name/tags/ports/comment), created via `vip-put` against
  `/api/v2/tailnet/{tailnet}/vip-services/{name}` -- **not**
  `/vip-services/by-name/{name}`, which 404s; see the script's own
  `vip_api()` comment for how that was found (a routing 404 with a bare
  "404 page not found" body versus this path's real JSON "service not
  found" 404 for a name that doesn't exist yet, confirming the route).
  This is a separate API resource from the ACL/policy file above -- a
  top-level `"services"` key in the *policy* file is rejected with
  `unknown field "services"`; that key belongs to the per-node *serve*
  config (nixpkgs' `services.tailscale.serve`), a different file
  entirely, confirmed the hard way before finding the right endpoint.

## What's NOT done yet

- `nire-cube` itself isn't tagged `tag:homelab-cube` -- nothing advertises
  either service yet. That's either a console action or
  `tailscale set --advertise-tags=tag:homelab-cube` run *on* cube.
- No NixOS `services.tailscale.serve` config exists to back these with
  the actual Grafana/Forgejo ports (3000/3001) -- see
  [reverse-proxy.md](../../../../../../wiki/categories/reverse-proxy.md)
  for the current Caddy-based routing this would replace.
- Caddy's `@grafana`/`handle_path /git` routes in `caddy.nix` are
  untouched and still serve the working `/grafana/`, `/git/` paths --
  nothing here has cut over.

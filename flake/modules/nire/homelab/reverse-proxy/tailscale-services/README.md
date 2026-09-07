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

- No NixOS `services.tailscale.serve` config exists to back these with
  the actual Grafana/Forgejo ports (3000/3001) -- see
  [reverse-proxy.md](../../../../../../wiki/categories/reverse-proxy.md)
  for the current Caddy-based routing this would replace.
- Caddy's `@grafana`/`handle_path /git` routes in `caddy.nix` are
  untouched and still serve the working `/grafana/`, `/git/` paths --
  nothing here has cut over.

## Tagging a device drops it out of `autogroup:members` -- live incident, 2026-09-07

`nire-cube` is now tagged `tag:homelab-cube` (`sudo tailscale up
--advertise-tags=tag:homelab-cube` run on cube -- **not** `tailscale set`,
which has no `--advertise-tags` flag on this tailscale version; only `up`
does, and unlike `set`'s doc-comment framing it does NOT reset flags left
unspecified). Within about a minute of that taking effect, `nire-cube`
vanished from *every other tailnet member's* `tailscale status` peer list
entirely -- not shown offline, absent -- and SSH to it failed
(`Could not resolve hostname`, then connection timeout by IP). Cube's own
`tailscale status` looked completely normal the whole time; this is
peer-visibility-only, easy to misread as cube itself being down.

Mechanism: a tagged device is owned by the tag, not by the user, for ACL
purposes -- so it drops out of `autogroup:members` as a grant
*destination*, same as any other member device would if nothing granted
access to it. This tailnet's only broad grant was
`autogroup:members -> autogroup:members`, which stopped covering cube the
moment the tag applied. The fix was one more grant, matching the pattern
`tag:golink-host` already uses in this same policy:

    {"src": ["autogroup:members"], "dst": ["tag:homelab-cube"], "ip": ["*"]}

**The rule this gives:** tagging ANY previously-untagged device needs its
own reachability grant applied in the same change, not after -- adding the
tag and the compensating grant are one atomic step, or the device drops off
the tailnet for everyone else the moment the tag takes effect.

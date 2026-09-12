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
- `svc-homepage.json` -- the third Service object. The first one under
  this name: `svc-glance.json` (deleted 2026-09-12, issue #291) was PUT
  2026-09-10, long after its `serve.nix` forward and Caddy vhost landed in
  PR #211 -- neither the policy file nor the Service object had ever been
  pushed, so `glance.moose-micro.ts.net` did not resolve at all while git
  and grafana did. Issue #291 renamed the landing page's service, which
  means a NEW object (`svc:homepage`) plus `vip-delete svc:glance` -- a
  rename in serve.nix is a fresh advertisement, not a rename on the
  control plane; the rollout order is in `landing/homepage/homepage.nix`'s
  history section. Note the API path takes the **`svc:`-prefixed** name:
  `vip-get svc:homepage`, not `vip-get homepage` -- the bare form 404s for
  every service, including ones that demonstrably exist, which makes it a
  useless existence check. (`tailscale-acl.py`'s own usage line still
  documents the older `by-name/NAME` path; the code at `vip_api()` is
  right, the docstring is stale.)
- **A Service answers only on the ports it declares, and the two halves
  must agree.** Each `svc-*.json`'s `ports` and the matching
  `endpoints."tcp:N"` in `serve.nix` both have to list a port before
  anything reaches Caddy on it. All three services declared `tcp:443`
  only until 2026-09-11, which left Caddy's `http://git`/`http://grafana`/
  `http://glance` redirect vhosts unreachable from the day they were
  written (issue #272) -- `http://ts-cube` worked throughout, because that
  is a real device address where Caddy binds 80 directly, which is what
  made the gap easy to miss.
- **`vip-put` needs `addrs` to UPDATE, but not to CREATE.** Updating an
  existing service 400s with `when updating a service, addrs must contain
  2 elements` -- it wants the v4/v6 VIPs the control plane already
  assigned. Those are assigned state, so they are deliberately NOT kept in
  the `svc-*.json` files (they would change on any delete/recreate and
  nothing would notice them going stale); `tailscale-acl.py`'s `vip-put`
  fetches and merges them instead, so these files stay a description of
  what is wanted.
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

## Status: svc:homepage created 2026-09-12 in this repo, APPLIED at switch time

Issue #291 renamed the landing page's Service. Everything in-repo moved
together (serve.nix `homepage` endpoints, caddy.nix `homepageFqdn` vhost,
this directory's `svc-homepage.json`, the ACL approver+grant in
`acl-diff-applied.hujson`); the tailnet moves at switch time -- apply, then
`vip-put svc:homepage`, then `vip-delete svc:glance`. Until then the record
here is AHEAD of the tailnet on exactly this one line, which the
`svc:glance` story below is the cautionary tale for -- `just tailscale-acl
diff` is what closes the gap.

## Status: grafana/git RUNTIME-VERIFIED 2026-09-07; glance NOT YET

**2026-09-10:** `svc:glance` created and the policy file re-POSTed (the
`svc:glance` autoApprover plus the `grants` entry svc:grafana/svc:git each
had and it didn't). `just tailscale-acl diff` reports **"no difference"** --
this directory and the live tailnet agree, which had not been true since
2026-09-09. `glance.moose-micro.ts.net` resolves tailnet-wide.

Finished 2026-09-11, but restarting `tailscale-serve` was NOT what
finished it -- that was tried twice (23:38, 23:59), both clean, and changed
nothing. cube already advertised `svc:glance`, the control-plane object was
identical in shape to the two that worked, and the policy file carried its
autoApprover and grant, yet the VIP refused connections **from cube
itself**.

**The rule this gives:** re-running `serve set-config` against an
already-standing advertisement does not activate a newly-created Service.
cube had carried `svc:glance` in its serve config since 2026-09-09, long
before the object existed to approve it against, so each `set-config`
re-sent an unchanged advertisement the control plane had no reason to act
on. A fresh registration is what it acts on:

```sh
systemctl restart tailscaled        # then, in this order:
systemctl restart tailscale-serve   # issue #267 -- it races tailscaled on boot
```

`CertDomains` then gained `glance.moose-micro.ts.net` and the VIP began
answering. Note the first request after activation fails the handshake
(`http=000`) while caddy fetches the cert -- retry, it is not a failure
state.

## Status: all three RUNTIME-VERIFIED; grafana/git 2026-09-07, glance 2026-09-11

Verified from tenacity 2026-09-11, all with `tls_verify_result` 0:
`glance` 200, `ts-cube` 200, `grafana` 302 (its real `/login`), `git` 200.
glance's cert is a real Let's Encrypt one issued through tailscaled.

## Status: grafana/git RUNTIME-VERIFIED end to end, 2026-09-07

Both services confirmed working on `nire-cube`: valid TLS (`tls_verify=0`)
on `https://grafana.moose-micro.ts.net/` (`302 -> /login`, real Grafana
content) and `https://git.moose-micro.ts.net/` (`200`, Forgejo's own
generated links correctly using the new `ROOT_URL`); the old
`ts-cube.../grafana/`, `.../git/` paths correctly `404`; backend ports
3000/3001 still loopback-only. See `serve.nix`'s own history section for
how the design got here (the first attempt didn't work) and
[reverse-proxy.md](../../../../../../wiki/categories/reverse-proxy.md)
for the full picture.

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

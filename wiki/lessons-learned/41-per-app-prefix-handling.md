# 41. A proxy config can be valid, buildable, *and* wrong per-app — two apps behind one prefix wanted opposite prefix handling

_Last modified: 2026-09-09_

§41 of [lessons-learned.md](../lessons-learned.md#41-a-proxy-config-can-be-valid-buildable-and-wrong-per-app--two-apps-behind-one-prefix-wanted-opposite-prefix-handling) — that page keeps the one-line version of every lesson; this is §41's full account.

`nire/reverse-proxy/caddy.nix`, 2026-08-24. Grafana and Forgejo were both
mounted under a path prefix on the same hostname
(`/grafana`, `/git`), and both were given the same Caddy directive,
`handle`, which passes the matched path through untouched.

Everything static passed, at four separate levels:

- `nix eval` of `nire-cube`'s toplevel — fine.
- `just modules` — no findings.
- `caddy adapt` on the generated Caddyfile, with the real 2.11.4 binary —
  clean, and it *had* already caught a different bug (`handle` takes at
  most one matcher token, so `handle /grafana /grafana/*` is a parse
  error).
- A real `just build` on the real x86_64-linux host, then reading the built
  artifact back: the rendered Caddyfile, the unit drop-in
  (`After=tailscaled.service`, the overridden `ExecStart`), the retained
  `AmbientCapabilities`, and `TS_PERMIT_CERT_UID=caddy` in tailscaled's own
  drop-in. All correct.

Then the first live request: `/grafana/` returned 200, `/git/` returned
**404**. Both halves of the config were valid Caddy; one of them was the
wrong choice for the app behind it.

The two apps want opposite things, and nothing in the config can tell you
which:

- **Grafana** has `serve_from_sub_path`, so it genuinely serves *under*
  `/grafana` and needs the prefix left on — `handle`.
- **Forgejo** has no equivalent. It always serves at `/`, and expects the
  proxy to strip — `handle_path`. Its `ROOT_URL` carrying `/git/` only
  controls the links it *generates*; it does not change what paths it
  answers on. This is the same thing Gitea/Forgejo's nginx docs encode in
  the trailing slash of `proxy_pass http://…:3001/;`, which is easy to read
  as cosmetic.

What settled it was one command against the running service, not more
reading: `curl 127.0.0.1:3001/` → 200, `curl 127.0.0.1:3001/git/` → 404.
That took seconds and was decisive, where the config itself could be
stared at indefinitely.

Two things to carry forward. **A shared mechanism does not imply shared
configuration** — "both are web apps behind the same proxy under the same
kind of prefix" hid a per-app requirement that runs in opposite
directions, and the symmetry of the two config blocks is exactly what made
it look right. And **the check that finds this is a request to the app
itself, not to the proxy**: the 404 was Forgejo's, not Caddy's, and
proving that (the fallback route would have returned the index text with
200 instead) is what pointed at the app rather than the routing.

Related to #36 (evaluating and building are different tests) and #37 (some
bugs need real runtime state) — this is the next rung: the artifact was
built *and* read *and* correct, and the defect was still only visible in
a response from the running service.

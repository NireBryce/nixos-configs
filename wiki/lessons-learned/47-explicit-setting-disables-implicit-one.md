# 47. An explicit setting can switch off an implicit one — auto-detection only fires where nothing is declared

_Last modified: 2026-09-11_

§47 of [lessons-learned.md](../lessons-learned.md#47-an-explicit-setting-can-switch-off-an-implicit-one--auto-detection-only-fires-where-nothing-is-declared) — that page keeps the one-line version of every lesson; this is §47's full account.

## What happened

2026-09-08, `nire-cube`. A commit added three bare-name convenience vhosts to
Caddy — `https://git`, `https://grafana`, `https://glance` — each carrying
`tls internal`, so that a browser typing the short name got a click-through
warning instead of an unrecoverable TLS alert. That part worked exactly as
intended.

It also took HTTPS down on four **other** vhosts —
`ts-cube`, `grafana`, `git` and `glance` under `.moose-micro.ts.net` — for
two days. Every one of them failed the handshake with
`tlsv1 alert internal error` (Firefox: `SSL_ERROR_INTERNAL_ERROR_ALERT`),
including `ts-cube.moose-micro.ts.net`, which no commit in that window had
touched and which had been runtime-verified working two weeks earlier.

## The mechanism

Three steps, none visible from the diff:

1. **The Caddyfile adapter emits automation policies for every site as soon
   as any site declares `tls`** — and not just for the site that declared it.
   Adding `tls internal` to three vhosts produced a policy whose subjects
   were the four *other*, `.ts.net` names, with no issuers and no managers.
   Confirmed by A/B: delete the three `tls internal` lines and `caddy adapt`
   emits `"tls": null`.
2. **Caddy's Tailscale-domain auto-detection only runs for names with no
   existing policy.** `autohttps.go`'s `uniqueDomainsLoop` does
   `continue uniqueDomainsLoop` the moment an explicit policy claims a name,
   so the `isTailscaleDomain` branch that would have attached
   `tls.get_certificate.tailscale` was never reached.
3. **The resulting issuer-less policy fell back to public ACME.**
   `Issuers == nil` is filled by `DefaultIssuersProvisioned`, so Caddy spent
   two days asking Let's Encrypt for certificates for tailnet names and
   getting NXDOMAIN — they have no public DNS. No certificate, so every
   handshake died.

## Why nothing caught it

`nix eval`, the build, `just modules` and even `caddy adapt` all passed. They
had to: **the generated Caddyfile was valid.** It simply meant something
other than what was intended. This is §37's shape ("some bugs need real
system state to exist at all") arriving through a new door — not a missing
check, but a check that cannot distinguish *valid* from *correct*.

The logs did not help either, and that was its own small lesson: nixpkgs'
`services.caddy.logFormat` defaults to `level ERROR`, which suppresses the
one `WARN` Caddy emits when the Tailscale cert manager declines. The failure
was loud in ACME retries and completely silent about its cause.

The comment in the module asserted the opposite of the truth — that
`tls internal` was "scoped per-vhost, does not touch … the tailscale cert
manager the FQDN vhosts above still use". It was written in good faith and
was wrong, which is why the fix corrected it in place rather than deleting
it.

## The general shape

**Declaring a thing explicitly can turn off the machinery that was handling
it implicitly** — and the two need not be the same thing, or even nearby.
Generators that assemble a global structure from per-item declarations
(policy lists, route tables, dependency graphs) routinely have a rule like
"defaults apply only where nothing was declared". Declare something for item
A, and item B silently changes category.

Questions worth asking before adding an explicit setting:

- Does this option get compiled into a *shared* structure, or does it stay on
  the thing I attached it to? (Reading the generator's output, not the input,
  answers it — here, `caddy adapt`.)
- Was something being handled automatically for the *other* items, and does
  that automation have a "only if not already specified" condition?
- Can I A/B the generated artifact with and without my line, and diff it?

## The fix, and why it's better than a revert

Naming the manager explicitly on each `.ts.net` vhost —
`tls { get_certificate tailscale }` — rather than relying on detection that
any future `tls` directive can switch off again.

That is strictly better than what it replaced, not a workaround:
`implicitTailscaleManagersOnly()` skips the default-ACME fill-in for a policy
whose subjects are all `.ts.net` and which carries a Tailscale manager, so
there is no public-CA fallback left to fail. A name `tailscaled` will not
issue for now fails closed instead of hammering Let's Encrypt.

Being explicit also makes the dependency greppable, which the implicit
version never was.

## See also

- [reverse-proxy](../categories/reverse-proxy.md) — the category, and the
  two-flavour bare-name situation this left behind.
- §37, §43 — the other two entries about checks that pass without proving
  what you wanted proved.
- `flake/modules/nire/homelab/reverse-proxy/caddy/caddy.nix` — the header
  carries the mechanism with `file:line` references into Caddy 2.11.4.

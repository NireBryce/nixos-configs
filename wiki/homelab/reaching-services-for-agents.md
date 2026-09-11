# Reaching cube's services, for agents

_Last modified: 2026-09-11_

Condensed from [reaching-services.md](reaching-services.md), which keeps the
reasoning, the retired-URL history and the verification record. Facts only
here.

Every web service on `nire-cube` has its own tailnet hostname and its own
certificate. Tailnet-only; nothing is exposed to the internet, and this is
not Funnel. Build side: [reverse-proxy](../categories/reverse-proxy.md).

## The map

| What | Full name | Short |
|---|---|---|
| glance (service index) | `https://glance.moose-micro.ts.net/` | `http://glance/` |
| Grafana | `https://grafana.moose-micro.ts.net/` | `http://grafana/` |
| Forgejo | `https://git.moose-micro.ts.net/` | `http://git/` |
| cube itself (also glance) | `https://ts-cube.moose-micro.ts.net/` | `http://ts-cube/` |
| golink (**not** on cube) | `http://go/` | — |

`ts-cube`, **not** `nire-cube` — this tailnet renames its devices.

Retired and 404/dead: `http://ts-cube:3000/` and `:3001/` (2026-08-24, both
apps moved to loopback); `.../grafana/` and `.../git/` path prefixes
(2026-09-07).

## Certificates

- **Full `.ts.net` names**: real publicly-trusted certs, issued by Tailscale
  and fetched by Caddy from the local `tailscaled`. Nothing to install.
- **`http://<short name>`**: a redirect, no certificate involved, lands on
  the real cert. **Use this form.**
- **`https://<short name>`**: `SEC_ERROR_UNKNOWN_ISSUER`, by design and
  unfixable — a bare name is not a `.ts.net` name, so no CA will ever issue
  for it and Caddy answers with its local CA. It exists only so a
  HTTPS-forcing browser gets a click-through instead of a hard failure.

Prefer the full name in bookmarks.

## When something doesn't answer

Ordered by what is most often actually wrong.

1. `tailscale status` on the machine you're browsing **from**.
2. **Does another service answer?** These are independent names on
   independent virtual addresses — "Grafana is down" and "cube is down" are
   different questions now.
3. `getent hosts git.moose-micro.ts.net`. **A Service name that doesn't
   resolve means the `svc:` object is missing or unapproved, not that the app
   is down.**
4. **Does that port answer?** A Service VIP listens only on ports its
   Service object *and* `serve.nix` both declare. A timeout on one port while
   another works on the same name is a missing endpoint, not a dead app.
5. `ping ts-cube`. A working `tailscale ping` with dead HTTP can be a tailnet
   grant blocking traffic — fixed in the policy file (`just tailscale-acl`),
   not in the app.
6. Over ssh:
   ```sh
   systemctl status caddy grafana forgejo glance tailscale-serve
   systemctl list-units --state=failed
   ```
   **Look at `NRestarts`, not just `active`** — a crash-loop reports `active`
   between restarts. Include `tailscale-serve`: when it fails every `svc:`
   name goes dark at once while cube's own name keeps working.
7. `journalctl -u <unit> -n 50`. **Caddy's log level is `ERROR` by default**,
   which hides the warning it emits when `tailscaled` declines a certificate.

**A TLS error is not a dead service.**
`SSL_ERROR_INTERNAL_ERROR_ALERT` on a `.ts.net` name means Caddy has no
certificate to offer — usually a config bug, not an outage. That exact
failure took down all four names for two days in September 2026.

## Adding a service

It binds loopback, gets its own `svc:` name, and needs three things to agree:
the Service object, `serve.nix`'s endpoints (**both `tcp:443` and
`tcp:80`**), and a Caddy vhost. Skill `new-tailscale-service`; skill
`new-homelab-service` for writing the module first.

## See also

[reaching-services.md](reaching-services.md) ·
[../categories/reverse-proxy-for-agents.md](../categories/reverse-proxy-for-agents.md)
· [forgejo.md](forgejo.md) · [README.md](README.md)

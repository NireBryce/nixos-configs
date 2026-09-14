# Name resolution & reverse DNS, for agents

_Last modified: 2026-09-14_

Condensed from [name-resolution.md](name-resolution.md). Config rationale
and the four name traps live in the modules — `tailscale.nix`,
`resolved.nix`, `avahi.nix` (all under `flake/modules/nire/system/networking/`)
and `flake/modules/nire/homelab/reverse-proxy/tailscale-services/README.md`
— not restated here. All behavioral claims probed live 2026-09-14 on
nire-tenacity unless a qualifier says otherwise.

## The sources

- MagicDNS (tailscaled, `100.100.100.100`): `*.moose-micro.ts.net` both
  directions — peer devices (`ts-cube`, `go`, `ts-iona`, …) AND `svc:`
  VIPs (`git`/`grafana`/`homepage`/`glance`). Reached via resolved's
  stub: tailscale0 carries routing domains `~moose-micro.ts.net`,
  `~100.100.in-addr.arpa`–`~107.100.in-addr.arpa`, tailnet `ip6.arpa`.
- avahi: `*.local`, LAN side only (`nire-cube.local` resolves
  LAN-local; the fallback when Tailscale is down on the client).
- LAN router (DHCP resolvers): everything else.
- golink = its own device (`go`, 100.98.81.59) — device rules, not a
  service VIP.
- `svc:` records arrive as netmap `ExtraRecords` and are
  visibility-granted: a tagged host gets none without a grant whose
  `src` is its tag (#298). Check:
  `tailscale status --json | jq .ExtraRecords`.

## Reverse (PTR)

`dig -x` / `getent hosts <ip>` on any fleet host, same answer direct to
`100.100.100.100` or via the stub:

- device 100.x → `ts-<name>.moose-micro.ts.net.` — the DEVICE name,
  never the `nire-` hostname (trap 1, reverse side).
- `svc:` VIP → its own name (`git.moose-micro.ts.net.`).
- v6 → works, same name as v4.
- If reverse fails, forward probably is too — run the ExtraRecords
  check above first.

## Where names render

- `tailscale status --json`: `.DNSName` is authoritative, can differ
  from `.HostName` (`samsung SM-S911U` → `ts-iona.moose-micro.ts.net.`).
- `getent hosts <ip>` → the PTR name; won't grep against
  `networking.hostName` for devices.
- ssh: connect by `ts-cube`, landed host says `hostname` = `nire-cube`.
  Both correct, different namespaces.
- Caddy on cube: NO peer addresses at all — tailscaled forwards over
  loopback, every request's `remote_ip` is `127.0.0.1` (journal-verified
  2026-09-14). Identify traffic by vhost (`server_name`/`host`), not by
  peer; per-request lines are error-level only (no access log
  configured). For "who hit this", read the app's logs or tailscaled's.

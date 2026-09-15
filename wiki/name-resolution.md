# Name resolution & reverse DNS

_Last modified: 2026-09-14_

Which name answers for what in this fleet — forward and reverse — and
where those names actually show up when you're reading logs, status
output, or a stalled ssh. Every behavioral claim below was probed live
on `nire-tenacity` against `100.100.100.100` and through the resolved
stub, 2026-09-14, per issue #294's ask; the *config* behind each
behavior is owned by the module named in the last section, and this
page links rather than restates it.

> **Condensed version:**
> [name-resolution-for-agents.md](name-resolution-for-agents.md) — the
> same ground with the narrative stripped out, for an agent (or a human
> in a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [Which name source answers for what](#which-name-source-answers-for-what)
- [Reverse DNS (PTR)](#reverse-dns-ptr)
- [Where names show up in practice](#where-names-show-up-in-practice)
- [Traps, and where the config lives](#traps-and-where-the-config-lives)

## Which name source answers for what

Three answering systems, cleanly divided:

- **MagicDNS (tailscaled, at `100.100.100.100`)** owns `*.moose-micro.ts.net`
  in both directions: every peer device (`ts-cube`, `ts-tenacity`, `go`,
  `ts-iona`, `homeassistant`, …) and every `svc:` Service VIP
  (`git`, `grafana`, `homepage`, `glance`). On a host it is reached not
  directly but through systemd-resolved, which tailscale0's per-link
  routing domains hand the tailnet domain *and* the reverse ranges to —
  so plain `dig -x`, `getent hosts`, and ssh all traverse the stub and
  land in the same place.
- **avahi/mDNS** owns `*.local` on the LAN side only —
  `nire-cube.local` resolves to the LAN address from a machine on the
  same LAN, and is the fallback name that still works when Tailscale is
  down on the client (see
  [Traps](#traps-and-where-the-config-lives)).
- **The LAN router (DHCP-provided resolvers)** own ordinary internet and
  LAN-unqualified names. Everything else falls through to them.

One device worth naming: **golink registers as its own tailnet device**
(`go`, IP 100.98.81.59) — so `go.moose-micro.ts.net` is a device name
with device rules, not a service VIP, and it appears in `tailscale
status` like any peer.

`svc:` names ride the same MagicDNS path as devices but reach a client
differently under the hood — as netmap `ExtraRecords`, which are
**visibility-granted**: a host whose only identity is a tag never
receives them without a grant whose `src` is that tag (found live,
issue #298; full story in
[../flake/modules/config-system/homelab/reverse-proxy/tailscale-services/README.md](../flake/modules/config-system/homelab/reverse-proxy/tailscale-services/README.md)).

## Reverse DNS (PTR)

tailscaled answers PTR for the whole CGNAT range, and it answers for
Service VIPs the same way as for devices — probed both directly
(`dig @100.100.100.100 -x`) and through the resolved stub, same
answers:

| query | answer |
|---|---|
| `-x` a device's 100.x IP | `ts-cube.moose-micro.ts.net.` — the **device** name, never `nire-cube` |
| `-x` an `svc:` VIP (100.117.139.169) | `git.moose-micro.ts.net.` |
| `-x` a device's tailnet IPv6 | works, same name as its v4 |

The reverse routing that makes the stub path work is visible in
`resolvectl status tailscale0`: tailscale0 claims
`~100.100.in-addr.arpa` through `~107.100.in-addr.arpa` plus the
tailnet's `ip6.arpa` range, alongside `~moose-micro.ts.net`. Nothing
about reverse lookups needs a separate config — if forward MagicDNS
works, reverse does too, and if it doesn't, the
[#298 check](https://github.com/NireBryce/nixos-configs/issues/298)
(`tailscale status --json | jq .ExtraRecords`) is where to look first.

Note what the device PTR says: **reverse lookup answers with the
`ts-` device name even though the machine's hostname is `nire-cube`.**
Piping an IP from a log through `getent hosts` yields a name that will
not grep against `networking.hostName` — that gap is trap 1 in
`tailscale.nix`, seen from the reverse side.

## Where names show up in practice

- **`tailscale status --json`**: each peer's `.DNSName` is the
  authoritative MagicDNS FQDN (trailing dot included), and it can differ
  from `.HostName` — the phone registered as `samsung SM-S911U` answers
  on the tailnet as `ts-iona.moose-micro.ts.net`. Trust `.DNSName` when
  scripting against peers.
- **`getent hosts <ip>`** on any fleet host: resolves the IP to the
  PTR name (device or service, per the table above) via nsswitch →
  resolved → tailscale0. This is the quick "which tailnet thing is
  100.x.y.z" command.
- **ssh**: you connect to `ts-cube`; the machine you land on reports its
  hostname as `nire-cube` (`hostname` on the far side). Both are
  correct; they are different namespaces.
- **Caddy on cube — peers do not appear at all.** tailscaled terminates
  the tailnet connection and forwards raw TCP over loopback to Caddy
  (that is the whole `svc:` design), so every request Caddy sees has
  `remote_ip: 127.0.0.1` — verified in cube's journal, 2026-09-14.
  Reverse DNS cannot show up in these logs because there is no peer
  address to resolve. Traffic is identified by vhost
  (`server_name`/`host` — `git.moose-micro.ts.net` etc.), and per-request
  lines appear only at error level since no site block configures an
  access log. Debugging "who hit this vhost" means the *app's* logs
  (Forgejo, Grafana) or tailscaled's, not Caddy's.

## Traps, and where the config lives

The config rationale and the four hard-won traps live in the modules —
read these before changing anything:

- `flake/modules/config-system/system/networking/tailscale.nix` — the
  `ts-`-vs-`nire-` device-name trap, the ACL-vs-firewall signature,
  the "tailnet name won't resolve → is Tailscale up on *your* machine?"
  rule and the `.local` fallback, and the tagging visibility incident.
  `flake/scripts/reach-host.sh` (`just reach <host>`) automates trying
  every real name a host answers to.
- `flake/modules/config-system/system/networking/resolved.nix` — why resolved
  has mDNS off globally (the 5353 coupling), and why tailscaled ends up
  in D-Bus/link-DNS mode instead of rewriting `/etc/resolv.conf`.
- `flake/modules/config-system/system/networking/avahi.nix` — the `.local` half
  and the publish settings that make hosts answer for their own names.
- `flake/modules/config-system/homelab/reverse-proxy/tailscale-services/README.md`
  — the `svc:` layer: Service objects, the tag/grant visibility rule
  (#298), and the activation dance.

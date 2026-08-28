# Hosts & current state

Canonical status lives in [`CLAUDE.md`'s State section](../CLAUDE.md#state)
— read that directly rather than trusting a count repeated here; it has been
wrong-for-a-day more than once as hosts were added. This page is just a map
of where to look for each host.

## The hosts

| Host | Class | Role | Wipes `/root`? |
|---|---|---|---|
| `nire-durandal` | nixos | workstation | yes |
| `nire-tenacity` | nixos | handheld (Jovian/SteamOS) | yes |
| `nire-cube` | nixos | mini PC (GMKtec) | **no** — deliberately, see below |
| `nire-lysithea` | darwin | laptop | n/a |

`nire-testbed` (ThinkPad X270) existed 2026-08-14 to 2026-08-22 and was
removed, never having been built or switched on real hardware. It's history
now, not a live host — see [history.md](history.md) and
[`../claude cave/lessons-learned.md`](<../claude cave/lessons-learned.md>).

`nire-lego` (handheld, Legion Go) and `nire-installer` (the generic live-USB
installer image) were both removed 2026-08-27 — see [history.md](history.md).

`nire-llm-sandbox` (a libvirt-managed guest on `nire-cube`, added 2026-08-22
and confirmed booted and staying up as of 2026-08-24) was removed
2026-08-28 — see [history.md](history.md) for what it was and what its
removal took with it; [virtualization](categories/virtualization.md) still
carries the generic generator it ran on.

`nire-cube` also runs a Prometheus + Grafana monitoring stack as of
2026-08-23 — see [monitoring](categories/monitoring.md). Grafana is reachable
over Tailscale only (same `trustedInterfaces` mechanism
[system](categories/system.md)'s Tailscale section documents); its
secret-key file-ownership bug took two rounds to actually fix (a same-day
hand fix regressed; the real fix, 2026-08-24, is a self-healing systemd
unit in the module itself — see that page's section on it) and is now
confirmed running.

`nire-cube` also runs Forgejo, a self-hosted git forge, as of 2026-08-24 —
see [git-forge](categories/git-forge.md). Same tailnet-only mechanism.
Confirmed working end to end the same day: `just switch` clean, both its
systemd units healthy, and a real `HTTP 200` from another tailnet host.

As of 2026-08-24 neither of those two is reached directly any more.
`nire-cube` runs Caddy — see [reverse-proxy](categories/reverse-proxy.md) —
which is the single tailnet-facing HTTPS listener on the host, holding a
certificate issued by the local `tailscaled` (no ACME, no plugin). Grafana
and Forgejo both moved to loopback in the same change and are now
`https://ts-cube.moose-micro.ts.net/grafana/` and `/git/` respectively; the
old `http://ts-cube:3000/` and `:3001/` URLs no longer answer, and
`http://ts-cube/` redirects. **Confirmed working end to end the same day**:
both paths return 200 over validated TLS from another tailnet host, 0 failed
units, `caddy` at `NRestarts=0`. It took two switches — the first served
Forgejo an un-stripped path prefix and it 404'd everything, a per-app
requirement no static check could see
([lessons-learned.md](<../claude cave/lessons-learned.md>) #41).

`https://ts-cube.moose-micro.ts.net/` itself serves
[glance](categories/landing.md), a service index added the same day: which
services are running, whether each is reachable *through the proxy*, and
cube's own CPU/memory/disk. Confirmed working on its first switch — all
three monitored sites (Grafana, Forgejo, golink) reporting OK.

`nire-cube` also runs golink, Tailscale's `go/foo` shortlink service, as of
2026-08-24 — see [shortlinks](categories/shortlinks.md). Its first real
switch **failed** (generation 13, a missing `AF_NETLINK` in the module's own
`RestrictAddressFamilies`, which Go's netlink interface enumeration needs).
Fixed and **confirmed working end to end the same day**: `NRestarts=0`, 0
failed units, the tailnet device `go` up, and `HTTP 200` from another tailnet
host. Creating links is [homelab/golinks.md](homelab/golinks.md). Not the same tailnet-only
mechanism either, and that's the part worth not misreading: golink embeds
tsnet, so it joins the tailnet as its *own device* (named `go`) and listens
there rather than on any of cube's interfaces — no firewall rule, no
`trustedInterfaces` reliance, and no dependency on the host's `tailscaled`.
It needs a one-time interactive login on first start (`journalctl -u golink
-f`, open the printed URL), because no `TS_AUTHKEY` is wired in — the same
call `tailscale.nix` makes for the host daemon.

`nire-cube` also gets a [backup](categories/backup.md) category as of
2026-08-28 — restic to the QNAP NAS already on the network, against issue
[#87](https://github.com/NireBryce/nixos-configs/issues/87). Unlike the
services above, **this one is evaluates-only, not switched**: two things
outside what Nix can close on its own — the repository password's actual
value, and a QNAP-side snapshot schedule for anti-deletion — are still
pending, and issue #87's own "done means" (a real Forgejo repo actually
recovered) hasn't been attempted. See the category page for both.

## Where each fact lives

- **Boot/switch status per host** — [`../CLAUDE.md`](../CLAUDE.md), State
  section. This is the file that gets corrected in place when status
  changes; nothing else should be treated as more current.
- **Why `nire-cube` doesn't wipe `/root`** —
  `flake/modules/nireHost/cube-configuration.nix` header comment, and
  [`../CLAUDE.md`](../CLAUDE.md)'s Safety section.
- **Adding a new host** — skill `new-host-config`
  (`.claude/skills/new-host-config/SKILL.md`): which category a new host
  wants, real hardware vs. not-yet-installed, what *not* to copy from the
  host you're basing it on.
- **Disk layout (LUKS + btrfs + impermanence)** —
  [`../flake/doc/disko-impermanence-layout.md`](<../flake/doc/disko-impermanence-layout.md>)
  — the reusable generator durandal/tenacity already run by hand, and
  the template if cube ever adopts impermanence instead of its current plain
  root.
- **Repo-wide layout and the impermanence warning** —
  [`../README.md`](../README.md) — the human-facing entry point; short,
  and the first thing to read before running any of this on real hardware.

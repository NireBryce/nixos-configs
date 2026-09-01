# `monitoring` — `nire/homelab/monitoring/`

Prometheus + Grafana, scraping this host's own resource metrics. Added
2026-08-23, cube-only so far — see [Imported by](#imported-by) for why that's
current state, not a structural limit.

Moved from `nire/monitoring/` to `nire/homelab/monitoring/` on 2026-08-27,
nested under a new umbrella `homelab` category alongside six other
self-hosted-service categories — see
[categories/README.md](README.md). The category name is unaffected.

As of 2026-08-24 Grafana is reached at
`https://ts-cube.moose-micro.ts.net/grafana/`, through Caddy
([reverse-proxy](reverse-proxy.md)) — **not** the `http://ts-cube:3000/` this
page described before, which no longer answers. Every listener in this
category is on loopback now. Confirmed working the same day: 200 over
validated TLS from another tailnet host.

## What's in it

Five files, all `nixos`-class:

- **`node-exporter/node-exporter.nix`** — host CPU/memory/disk/network
  metrics. Loopback-only (`127.0.0.1`); nothing outside the host queries it
  directly.
- **`cadvisor/cadvisor.nix`** — per-container metrics for the podman
  containers [containers](containers.md) enables. Also loopback-only. Not
  runtime-verified against podman specifically — cadvisor falls back to
  walking cgroups directly without a docker-compatible socket, which is
  expected to surface podman's containers too, just labelled by raw cgroup
  path rather than name until/unless `virtualisation.podman.dockerSocket` is
  wired up.
- **`libvirt-exporter/libvirt-exporter.nix`** — per-VM state/CPU/memory/
  disk/network metrics for the libvirt/QEMU guests
  [virtualization](virtualization.md) defines on this host, via
  `prometheus-libvirt-exporter` against `qemu:///system` (the same
  connection `libvirt.nix` points `virt-manager` at). Also loopback-only.
  Overrides the exporter's default `group` to `libvirtd` — its own default
  group has no access to libvirtd's socket
  (`/run/libvirt/libvirt-sock`, group `libvirtd`, mode `0770`), so without
  this it starts and silently serves an empty metrics page rather than
  failing loudly.
- **`prometheus/prometheus.nix`** — scrapes the three exporters above over
  loopback. Also loopback-only itself; nothing outside the host queries
  Prometheus directly either.
- **`grafana/grafana.nix`** — the one service in this stack meant to be
  reached off-host, and the only piece with anything non-obvious in it (see
  below). Ships one provisioned dashboard,
  `grafana/_dashboards/nire-cube-overview.json` — three rows (system basics,
  libvirt/QEMU VMs, podman containers). The dashboards directory is
  underscore-prefixed for the same reason `VMs/_lib/` is in
  [virtualization](virtualization.md): `import-tree` ignores any path
  containing `/_`, so the JSON in there is never mistaken for a flake-parts
  module to import.

## Tailnet-only access, not a new firewall mechanism

Grafana binds `127.0.0.1:3000` as of 2026-08-24, so the whole category is
loopback-only and nothing outside cube can open a connection to any of it.
Its port is deliberately **not** in `networking.firewall.allowedTCPPorts`,
but that is no longer what restricts access — the binding is.

Grafana bound `0.0.0.0` from 2026-08-23 until then, because nothing else on
the host could accept the connection on its behalf, and the
`trustedInterfaces = [ "tailscale0" ]` rule [system](system.md)'s
`tailscale.nix` sets on every host was the only thing between port 3000 and
the LAN: traffic arriving on `tailscale0` bypasses the allow-list entirely,
traffic arriving on any other interface hits the default-deny.

That rule still applies, to Caddy's 443 now
([reverse-proxy](reverse-proxy.md)), and the same caveat with it:
`trustedInterfaces` trusts the *whole* interface, not one port — the blanket
trust ssh/kde-connect already get on every host, not something this category
introduces. What changed is that it is the second line rather than the only
one. Two settings in `grafana.nix` exist purely because of the proxy
(`http_addr`, and `root_url`/`serve_from_sub_path` for the `/grafana` path
prefix); its own history note at the bottom of the file has the before/after.

## The secret_key trap, and why it's now a unit instead of a warning

Found on `nire-cube`'s first real `just switch` with this category —
[hosts.md](../hosts.md) has the current switch status.

- **`services.grafana.settings.security.secret_key` has no default as of
  nixpkgs 26.05** — a hard eval-time assertion, not a warning. Pointed at
  Grafana's own file-provider syntax
  (`$__file{/persist/secrets/grafana-secret-key}`, read by Grafana at
  service start, never by Nix) rather than sops — same reasoning
  [elly's `hashedPasswordFile`](../impermanence-and-secrets.md) gets a
  hand-created file instead of a secrets entry on this specific host.
- **The file has to be owned by the `grafana` user, not root.**
  `services.grafana` runs its systemd unit as `User = "grafana"` (upstream
  nixpkgs), and creating the secret the obvious way —
  `sudo install -m600 ...` — produces a `root:root` file that user can't
  read. Grafana starts, can't read its own secret key, and dies, with
  nothing more specific than "failed" in `systemctl status`'s default view.

A `warnings` entry describing a two-step manual fix (`install`, then
`chown`) used to sit here — fixed by hand once, 2026-08-23, then found
**regressed to the exact same `root:root` state** on a live re-check
2026-08-24, `grafana.service` actively crash-looping the whole time nobody
happened to check. A hand fix regressing once was reason enough not to
trust a second hand fix either: `grafana-secret-key-setup.service`
(`grafana.nix`) replaced the warning, a oneshot ordered before
`grafana.service` on *every* activation that generates the secret only if
missing and unconditionally reasserts ownership/mode — modeled on
`services.forgejo`'s own upstream `forgejo-secrets.service`
([git-forge](git-forge.md)), though checking `services.grafana`'s own
nixpkgs module first showed this isn't idiomatic *to Grafana specifically*:
it used to have a `secretKeyFile` option and nixpkgs removed it in favor of
exactly this "the deployer manages it" file-provider approach, with an
explicit warning that there's no official way to rotate `secret_key` — so
the unit only ever *creates* a missing file, never regenerates an existing
one; only ownership/mode are safe to reassert unconditionally, and that's
the part that kept regressing. **Confirmed working end to end, 2026-08-24**:
`sudo systemctl restart grafana.service` (needed once, since a brand-new
unit added by `switch` doesn't retroactively get pulled into an
already-running `grafana.service`) ran the setup unit first
(`0/SUCCESS`), and `grafana.service` came back up with the secret file's
mtime unchanged and ownership `grafana:grafana`.

A third, unrelated thing broke in the same `switch` and is **not** part of
this category: the sandbox VM (`nire-llm-sandbox`) failed with `network
'default' is not active` — that's [virtualization](virtualization.md)'s
libvirt default network never being started, fixed in `libvirt-vm.nix`
itself rather than here. Two independent failures in one activation log are
easy to conflate; they had nothing to do with each other beyond landing in
the same `just switch` output.

## Why cube only, and why that's a category rather than a host-specific file

Same reasoning [virtualization](virtualization.md) and
[containers](containers.md) already give: `nire/system/` is imported whole
by every Linux host with no way to opt a piece of it out, so anything that
should be optional needs its own category (see
[../architecture.md](../architecture.md), "if something shared needs to be
optional, a category is the mechanism"). Nothing here is `system`-scoped
today — it's a fresh category from the start — but the same logic applies
looking forward: if a second host ever wants this stack, importing
`monitoring` there costs one line, no reshuffle.

## Imported by

`nire-cube` only, as of 2026-08-23. Not durandal or tenacity — no
design reason rules them out, it just hasn't been asked for there yet.

## See also

- [reverse-proxy](reverse-proxy.md) — Caddy, how Grafana is reached as of
  2026-08-24, and where its TLS certificate comes from.
- [system](system.md) — `tailscale.nix`, the firewall rule this category's
  access model still rests on, one layer out.
- [virtualization](virtualization.md) — what `libvirt-exporter.nix` scrapes,
  and the unrelated network-start bug found in the same activation.
- [containers](containers.md) — what `cadvisor.nix` scrapes.
- [impermanence-and-secrets.md](../impermanence-and-secrets.md) — why
  `grafana.nix`'s `secret_key` doesn't go through sops either (cube has no
  impermanence to lose the file to), and how that's diverged from elly's
  `hashedPasswordFile`, the other file in that category.
- [git-forge](git-forge.md) — `forgejo-secrets.service`, the upstream
  pattern `grafana-secret-key-setup.service` above is modeled on.
- [hosts.md](../hosts.md) — current switch/verification status for
  `nire-cube`.

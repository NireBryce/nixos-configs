# `monitoring` — `nire/monitoring/`

Prometheus + Grafana, scraping this host's own resource metrics. Added
2026-08-23, cube-only so far — see [Imported by](#imported-by) for why that's
current state, not a structural limit.

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

Grafana binds `0.0.0.0:3000`, but its port is deliberately **not** added to
`networking.firewall.allowedTCPPorts`. What actually restricts access is the
`trustedInterfaces = [ "tailscale0" ]` rule [system](system.md)'s
`tailscale.nix` already sets on every host: traffic arriving on
`tailscale0` bypasses the allow-list entirely, traffic arriving on any other
interface hits the default-deny. Same mechanism `CLAUDE.md`'s Tailscale
section documents for the daemon's own port, applied to a second service
rather than reinvented. Worth keeping in view: `trustedInterfaces` trusts the
*whole* interface, not just this one port — the same blanket trust
ssh/kde-connect already get on every host, not something this category
introduces.

## Two runtime-verified traps, both in `grafana.nix`'s own header

Found on `nire-cube`'s first real `just switch` with this category —
[hosts.md](../hosts.md) has the current switch status.

- **`services.grafana.settings.security.secret_key` has no default as of
  nixpkgs 26.05** — a hard eval-time assertion, not a warning. Pointed at
  Grafana's own file-provider syntax
  (`$__file{/persist/secrets/grafana-secret-key}`, read by Grafana at
  service start, never by Nix) rather than sops — same reasoning
  [elly's `hashedPasswordFile`](../impermanence-and-secrets.md) gets a
  hand-created file instead of a secrets entry on this specific host. A
  `warnings` entry fires until that file exists, mirroring
  `WARN-password-required.nix`.
- **The file has to be owned by the `grafana` user, not root.**
  `services.grafana` runs its systemd unit as `User = "grafana"` (upstream
  nixpkgs), and creating the secret the obvious way —
  `sudo install -m600 ...` — produces a `root:root` file that user can't
  read. Grafana starts, can't read its own secret key, and dies, with
  nothing more specific than "failed" in `systemctl status`'s default view.
  Fixed as a documented two-step (`install` as root, then `chown
  grafana:grafana`) in the `warnings` text itself.

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

`nire-cube` only, as of 2026-08-23. Not durandal, tenacity, or lego — no
design reason rules them out, it just hasn't been asked for there yet.

## See also

- [system](system.md) — `tailscale.nix`, the firewall rule this category's
  entire access model depends on.
- [virtualization](virtualization.md) — what `libvirt-exporter.nix` scrapes,
  and the unrelated network-start bug found in the same activation.
- [containers](containers.md) — what `cadvisor.nix` scrapes.
- [impermanence-and-secrets.md](../impermanence-and-secrets.md) — the
  hand-created-file pattern `grafana.nix`'s `secret_key` follows instead of
  sops, and why (cube has no impermanence to lose the file to, but nothing
  in this repo creates it either).
- [hosts.md](../hosts.md) — current switch/verification status for
  `nire-cube`.

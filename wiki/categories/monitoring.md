# `monitoring` — `nire/homelab/monitoring/`

_Last modified: 2026-09-07_

## Contents

- [What's in it](#whats-in-it)
- [Tailnet-only access, not a new firewall mechanism](#tailnet-only-access-not-a-new-firewall-mechanism)
- [The secret_key trap, and why it's now a unit instead of a warning](#the-secret_key-trap-and-why-its-now-a-unit-instead-of-a-warning)
- [Adding a dashboard that survives a rebuild](#adding-a-dashboard-that-survives-a-rebuild)
- [Why cube only, and why that's a category rather than a host-specific file](#why-cube-only-and-why-thats-a-category-rather-than-a-host-specific-file)
- [Imported by](#imported-by)
- [See also](#see-also)

Prometheus + Grafana, scraping this host's own resource metrics. Added
2026-08-23, cube-only so far; nested under the `homelab` umbrella since
2026-08-27 (name unaffected).

As of 2026-09-07 Grafana is reached at `https://grafana.moose-micro.ts.net/`
— its own Tailscale Services name, still fronted by Caddy
([reverse-proxy](reverse-proxy.md)) since Tailscale Services can't
terminate HTTPS declaratively yet (a confirmed upstream bug, see
`tailscale-services/serve.nix`'s history section). The
`.../grafana/`-path-under-`ts-cube` form this page described from
2026-08-24 no longer answers (404). Every listener in this category is on
loopback either way. Confirmed working 2026-09-07: 200 over validated TLS
from another tailnet host, Grafana's own login redirect (`302 -> /login`)
observed correctly.

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
one. `http_addr` stays loopback in `grafana.nix` for this reason; `root_url`
now points at `grafana.moose-micro.ts.net` (its own Tailscale Services name)
instead of a path under `ts-cube` — `serve_from_sub_path` is gone, since
Grafana has its own vhost rather than sharing one under a prefix. The
file's own history note has the full before/after.

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

`grafana-secret-key-setup.service` (`grafana.nix`) generates the secret
only if missing and unconditionally reasserts ownership/mode, modeled on
`services.forgejo`'s upstream `forgejo-secrets.service`
([git-forge](git-forge.md)) — nixpkgs removed Grafana's own
`secretKeyFile` option in favor of exactly this "the deployer manages it"
file-provider approach, with no official way to rotate `secret_key`, so
the unit only ever *creates* a missing file and never regenerates one.
Replaced a hand-fixed file that regressed twice before this landed —
[monitoring-history.md](monitoring-history.md) has that chronology and the
confirmation this unit actually fixed it.

## Adding a dashboard that survives a rebuild

The missing piece [open-threads.md](../open-threads.md) used to flag: a
dashboard built in the Grafana UI lives only in cube's sqlite db (now
[backed up](backup.md), but still not *declared* — a rebuild that
reprovisions `_dashboards/` doesn't touch the db, but the db is still the
only copy of anything not checked in here).

`grafana.nix`'s `dashboards.settings.providers` points a `file` provider at
`./_dashboards`, so getting a UI dashboard into the repo is exporting its
JSON there — no extra plumbing needed:

1. In the dashboard, **Settings → JSON Model** (or the export button) and
   copy the JSON.
2. Give it a **fixed `"uid"`** (a short slug, like the existing
   `"nire-cube-overview"`) if the exported one is a random-looking string —
   this is what makes reprovisioning it idempotent rather than creating a
   duplicate every switch.
3. **Drop the top-level `"id"` field entirely** if present — the existing
   `nire-cube-overview.json` has none; Grafana's file provider keys on
   `uid`, and a stale numeric `id` from the exported instance doesn't mean
   anything on a fresh provision.
4. Point every panel's `datasource.uid` at the fixed
   `prometheusDatasourceUid` (`"prometheus-cube"`, declared once in
   `grafana.nix`) instead of leaving Grafana's own `${DS_PROMETHEUS}`
   template variable in the export — the existing dashboard does this
   throughout (`grep -c '"uid": "prometheus-cube"'` on it agrees), and it's
   *why* the datasource and dashboard can both be plain provisioned files
   with nothing to resolve at import time.
5. Save the file under `grafana/_dashboards/`, `just switch`, confirm the
   dashboard reappears with its panels intact.

**Not verified against a live export** — written from `grafana.nix`'s own
mechanism and `nire-cube-overview.json`'s shape, not by actually exporting
a UI-built dashboard and round-tripping it through a switch. Worth doing
once before trusting this blindly.

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

- [homelab/README.md](../homelab/README.md) — Grafana is listed there under
  "Also running, not yet written up": reachable and confirmed working, just
  no usage-tier page yet since logging in and reading the provisioned
  dashboards needs little explaining.
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
- [monitoring-history.md](monitoring-history.md) — the `secret_key`
  regression, twice, and the unrelated VM failure in the same activation.

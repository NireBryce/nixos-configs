# `monitoring`, for agents

_Last modified: 2026-09-26_

Condensed from [monitoring.md](monitoring.md), which keeps the reasoning
and the narrative. Facts only here.

Prometheus + Grafana on `nire-cube`. Added 2026-08-23, nested under
`homelab` 2026-08-27. Reached at `https://grafana.moose-micro.ts.net/`
since 2026-09-07; the old `.../grafana/` path 404s.

## What's in it

`config-system/homelab/monitoring/`, seven files, all `nixos`-class, **every listener
on loopback**:

| File | Scrapes | Note |
|---|---|---|
| `node-exporter/node-exporter.nix` | host CPU/mem/disk/net | |
| `cadvisor/cadvisor.nix` | podman containers | not runtime-verified against podman; falls back to walking cgroups, so containers show by cgroup path not name unless `virtualisation.podman.dockerSocket` is wired |
| `libvirt-exporter/libvirt-exporter.nix` | libvirt/QEMU guests via `qemu:///system` | **overrides `group` to `libvirtd`** — its default group can't read `/run/libvirt/libvirt-sock` and it then serves an empty metrics page instead of failing |
| `smartctl-exporter/smartctl-exporter.nix` | per-disk SMART/NVMe wear (health, percentage used, media errors, temperature) | added 2026-09-21; `devices` left `[]` (autodiscover). **No dashboard panel yet** — `smartctl_device_*` metric names weren't confirmed against live `/metrics` before landing this; check that on cube first |
| `prometheus/prometheus.nix` | the four above, over loopback | |
| `runner-alerts/runner-alerts.nix` | textfile metrics (`/var/lib/node-exporter-textfile`: `forge_runner_egress_dropped_packets_total{reason}`, `forge_runner_dns_refused_5m`, cycle gauges from actions-runner.nix) + systemd collector (unit-include: forge-runner-cycle, vm-egress-dns, libvirt-vm-forge-runner) | 6 provisioned Grafana alert rules: 5 in folder `forge-runner`, plus `cube-root-disk-low` (folder `cube`, / under 10% free for 15m); datasource UID looked up from grafana.nix's provisioned datasources; checked by loading the built provisioning into Grafana 13.1.6 locally |
| `grafana/grafana.nix` | — | the only off-host-facing piece. Ships two provisioned dashboards: `nire-cube-overview.json` (three rows) and `roundtrip-check.json` (one panel, the export-verification artifact) |

`grafana/_dashboards/` is underscore-prefixed because `import-tree` ignores
any path containing `/_` — otherwise the JSON would be taken for a module.

## Traps

- **`services.grafana.settings.security.secret_key` has no default** as of
  nixpkgs 26.05 — a hard eval-time assertion, not a warning.
- **The secret file must be owned by the `grafana` user.** The unit runs as
  `User = "grafana"`; `sudo install -m600` gives you `root:root`, Grafana
  dies, and `systemctl status` says only "failed".
  `grafana-secret-key-setup.service` handles both: create-if-missing,
  reassert ownership unconditionally, **never regenerate** (there is no
  supported way to rotate `secret_key`). Modeled on upstream
  `forgejo-secrets.service`.
- Secret is read by Grafana, not Nix:
  `$__file{/persist/secrets/grafana-secret-key}`. Not sops.
- **`admin_password` IS sops** (`grafana-admin-password`, `owner = "grafana"`,
  added 2026-09-13) via the same `$__file{}` provider. **First start only** —
  Grafana's `defaults.ini`: "can be changed before first start". Stops a
  rebuilt instance coming up on stock `admin`/`admin`; does not manage a live
  password. `grafana-cli admin reset-admin-password` per activation is what
  would, and is deliberately not done.
- `http_addr` stays loopback; `root_url` is the Tailscale Services name.
  `serve_from_sub_path` is gone with the path prefix.
- No firewall port. Access is restricted by the **binding**, not by
  `trustedInterfaces` — that's the second line now, and it trusts the whole
  interface, not one port.

## Adding a dashboard that survives a rebuild

`dashboards.settings.providers` points a `file` provider at `./_dashboards`,
so exporting the JSON there is the whole job:

1. Settings → JSON Model, copy.
2. Give it a **fixed `"uid"`** (slug, like `nire-cube-overview`) — this is
   what makes reprovisioning idempotent instead of duplicating.
3. **Drop any top-level `"id"`.**
4. Point every panel's `datasource.uid` at `"prometheus-cube"`, not
   Grafana's `${DS_PROMETHEUS}` template variable.
5. Save under `grafana/_dashboards/`, `just switch`, confirm panels intact.

**Verified end to end 2026-09-11.** A UI-shaped dashboard (random uid,
top-level `id`, `${DS_PROMETHEUS}` panels) was created on cube over the API,
exported, and carried through steps 2–4 into `roundtrip-check.json`; every
transformation the steps predict was the one needed. The switch leg then ran
on cube: Grafana's API lists exactly two dashboards (no duplicate),
`roundtrip-check` reports `provisioned: True` with `provisionedExternalId:
roundtrip-check.json` (file-sourced, not a db leftover), the panel queries
live through the datasource proxy, and `nix store diff-closures` shows the
deployed generation matching the tree.

A UI-built dashboard lives only in cube's sqlite db. It is backed up, but
not declared.

## Imported by

`nire-cube` only. Not durandal or tenacity — no design reason, just
unasked-for.

## See also

[monitoring.md](monitoring.md) · [reverse-proxy.md](reverse-proxy.md) ·
[git-forge.md](git-forge.md) · [system.md](system.md) ·
[monitoring-history.md](monitoring-history.md)

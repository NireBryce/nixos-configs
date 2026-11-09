# `monitoring`, for agents

_Last modified: 2026-11-08_

_Sibling reviewed: 2026-11-08 -- alerts moved from Grafana rules to Prometheus rules + Alertmanager; QNAP SNMP added_

Condensed from [monitoring.md](monitoring.md).

Prometheus + Alertmanager + Grafana on `nire-cube`. Added 2026-08-23, nested under
`homelab` 2026-08-27. Reached at `https://grafana.moose-micro.ts.net/`
since 2026-09-07; the old `.../grafana/` path 404s.

## Category contents

`homelab-config/homelab/monitoring/`, all `nixos`-class, **every listener
on loopback**:

| File | Scrapes | Note |
|---|---|---|
| `node-exporter/node-exporter.nix` | host CPU/mem/disk/net | |
| `cadvisor/cadvisor.nix` | podman containers | not runtime-verified against podman; falls back to walking cgroups, so containers show by cgroup path not name unless `virtualisation.podman.dockerSocket` is wired |
| `libvirt-exporter/libvirt-exporter.nix` | libvirt/QEMU guests via `qemu:///system` | **overrides `group` to `libvirtd`** — its default group can't read `/run/libvirt/libvirt-sock` and it then serves an empty metrics page instead of failing |
| `smartctl-exporter/smartctl-exporter.nix` | per-disk SMART/NVMe wear (health, percentage used, media errors, temperature) | added 2026-09-21; `devices` left `[]` (autodiscover). **No dashboard panel yet** — `smartctl_device_*` metric names weren't confirmed against live `/metrics` before landing this; check that on cube first |
| `prometheus/prometheus.nix` | the exporters above, over loopback | |
| `runner-alerts/runner-alerts.nix` | textfile metrics (`/var/lib/node-exporter-textfile`: `forge_runner_egress_dropped_packets_total{reason}`, `forge_runner_dns_refused_5m`, cycle gauges from actions-runner.nix) + systemd collector (unit-include: forge-runner-cycle, vm-egress-dns, libvirt-vm-forge-runner) | Prometheus alert rules (areas `forge-runner`, `cube`; `cube` is low free space on /); were Grafana-provisioned rules until 2026-11-08, ported to PromQL with `absent()` where the old rule alerted on no data. Rules pass promtool in the build; not yet runtime-verified |
| `snmp-exporter/snmp-exporter.nix` | `ts-hive` QNAP over SNMPv3 (SHA, DES), `qnap` job in prometheus.nix | standard MIBs only; QNAP disk/volume tables need the NAS's MIB. Credentials in sops key `snmp-exporter-env` (multi-line env file); activation fails until the key is in secrets.yaml. Build runs `snmp_exporter --dry-run`; not runtime-verified, the NAS was never queried |
| `qnap-alerts/qnap-alerts.nix` | — | rules `QnapUnreachable`, `QnapVolumeAlmostFull`; the volume rule's `hrStorageDescr=~"/share/.*"` is a guess |
| `alertmanager/alertmanager.nix` | — | loopback; `default` receiver has no channel, so nothing is sent yet; Grafana views it via the `alertmanager-cube` datasource |
| `grafana/grafana.nix` | — | the only off-host-facing piece. Ships provisioned dashboards: `nire-cube-overview.json` and `roundtrip-check.json` (the export-verification artifact) |

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

Verified end to end on cube 2026-09-11 (`roundtrip-check.json`): no
duplicate dashboard, `provisioned: True`, panel queries live.

A UI-built dashboard lives only in cube's sqlite db. It is backed up, but
not declared.

## Imported by

`nire-cube` only.

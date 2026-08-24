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
| `nire-lego` | nixos | handheld, Legion Go (Jovian/SteamOS) | yes |
| `nire-cube` | nixos | mini PC (GMKtec) | **no** — deliberately, see below |
| `nire-lysithea` | darwin | laptop | n/a |
| `nire-installer` | nixos | live-USB installer, not a persistent host | n/a — no persistent `/root` at all |
| `nire-llm-sandbox` | nixos | libvirt VM guest (Claude Code sandbox), runs on `nire-cube` | n/a — persistent guest disk, not part of the impermanence fleet |

`nire-testbed` (ThinkPad X270) existed 2026-08-14 to 2026-08-22 and was
removed, never having been built or switched on real hardware. It's history
now, not a live host — see [history.md](history.md) and
[`../claude cave/lessons-learned.md`](<../claude cave/lessons-learned.md>).

`nire-llm-sandbox`, added 2026-08-22, is a third shape alongside "real host"
and "live-USB image": a `nixosConfigurations` entry that exists to build a
qcow2 disk image (same pattern `nire-installer` uses for its ISO), but
unlike the installer it's meant to run *persistently* once started, as a
libvirt-managed guest on `nire-cube` — see
[virtualization](categories/virtualization.md)'s own section on it, and
skill `nixos-vm-images` for the mechanism. `nire-cube`'s first real `just
switch` with this VM wired in (2026-08-23) hit a real bug — libvirt's
default network was defined but never started, so the VM's own activation
service failed outright — fixed the same day (see
[virtualization](categories/virtualization.md)). Still **not yet confirmed
to actually boot**; the fix landed but hasn't been watched succeed on the
real host yet, same "evaluates/builds ≠ verified" gap this page's own
installer walkthrough note already flags for a different reason.

`nire-cube` also runs a Prometheus + Grafana monitoring stack as of
2026-08-23 — see [monitoring](categories/monitoring.md). Grafana is reachable
over Tailscale only (same `trustedInterfaces` mechanism
[system](categories/system.md)'s Tailscale section documents); confirmed
running after a same-day fix to a file-ownership bug in its own secret-key
setup (see that page's traps section).

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
- **Building/installing a host with the live-USB image** —
  [`../flake/modules/nireHost/installer/liveusb-installer.md`](<../flake/modules/nireHost/installer/liveusb-installer.md>)
  — full walkthrough, generalized 2026-08-22 to target any host at build
  time. Untested against real hardware since that generalization; read the
  partition-layout step skeptically.
- **Disk layout (LUKS + btrfs + impermanence)** —
  [`../flake/doc/disko-impermanence-layout.md`](<../flake/doc/disko-impermanence-layout.md>)
  — the reusable generator durandal/tenacity/lego already run by hand, and
  the template if cube ever adopts impermanence instead of its current plain
  root.
- **Repo-wide layout and the impermanence warning** —
  [`../README.md`](../README.md) — the human-facing entry point; short,
  and the first thing to read before running any of this on real hardware.

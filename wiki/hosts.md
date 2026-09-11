# Hosts & current state

_Last modified: 2026-09-11_

## Contents

- [The hosts](#the-hosts)
- [Where each fact lives](#where-each-fact-lives)

This page is a map of where to look for each host. **Switch state is not
recorded anywhere in the repo** — it rots faster than any session can
correct it, so "is this host running the current build?" is answered live
on the host (`just baseline`, `just diff-deployed`, or comparing `nix eval
...toplevel.outPath` against `readlink /run/current-system`); see
[`AGENTS.md`'s State section](../AGENTS.md#state).

## The hosts

| Host | Class | Role | Wipes `/root`? |
|---|---|---|---|
| `nire-durandal` | nixos | workstation | yes |
| `nire-tenacity` | nixos | handheld (Jovian/SteamOS) | yes |
| `nire-cube` | nixos | mini PC (GMKtec) | **no** — deliberately, see below |
| `nire-lysithea` | darwin | laptop | n/a |

Removed, history not live hosts ([history.md](history.md)): `nire-testbed`
(2026-08-14→08-22, never on real hardware), `nire-lego` and `nire-installer`
(2026-08-27), `nire-llm-sandbox` (2026-08-28; the generic libvirt generator
it ran on survives under [virtualization](categories/virtualization.md)).

`nire-tenacity` known quirk: mouse/input feels unresponsive for ~4.5s after
resume from suspend. Not a USB/kernel issue — `handheld-daemon`'s `adjustor`
plugin deliberately delays reapplying TDP/GPU/governor settings after wake;
see [desktop-env.md](categories/desktop-env.md#known-quirk-mouseinput-lag-for-45s-after-resume-on-tenacity)
for the mechanism. Diagnosed 2026-09-06, not worth chasing.

What cube runs, each with its own page — including per-service verification
status and what broke on the way:

- [monitoring](categories/monitoring.md) — Prometheus + Grafana (2026-08-23;
  the Grafana secret-key fix took two rounds — the hand fix regressed).
- [git-forge](categories/git-forge.md) — Forgejo (2026-08-24).
- [reverse-proxy](categories/reverse-proxy.md) — Caddy, the single
  tailnet-facing HTTPS listener, with certs issued by `tailscaled`. Each web
  service has its own tailnet name since 2026-09-07
  (`grafana.`/`git.`/`glance.moose-micro.ts.net`); the `/grafana/` and
  `/git/` path prefixes they used from 2026-08-24 are retired. URLs:
  [homelab/reaching-services.md](homelab/reaching-services.md).
- [landing](categories/landing.md) — glance at `/` (2026-08-24).
- [shortlinks](categories/shortlinks.md) — golink (2026-08-24). Not behind
  Caddy and not a host service: it embeds tsnet and joins the tailnet as its
  own device `go`, needing a one-time interactive login on first start.
- [backup](categories/backup.md) — restic to the QNAP (2026-08-28, issue
  [#87](https://github.com/NireBryce/nixos-configs/issues/87)); local-path
  over NFS failed for real, SFTP since 2026-08-31. **Done as of
  2026-09-06**, restore drill included (run twice — found and fixed a real
  sqlite-staging bug, then confirmed). Still no backups on durandal/
  tenacity/lysithea ([#130](https://github.com/NireBryce/nixos-configs/issues/130)).
  Runbook: [homelab/backup-runbook.md](homelab/backup-runbook.md).
- opencode server —
  [`flake/modules/nireHost/cube/configuration/opencode-server-cube.nix`](<../flake/modules/nireHost/cube/configuration/opencode-server-cube.nix>)
  (2026-09-07). Not a category: one personal dev tool, not part of the
  self-hosted stack. Runs `opencode serve` as a systemd user service bound
  to the tailnet IP only — `just opencode-attach` (`-c` resumes the last
  session after a TUI exit).

## Where each fact lives

- **What a host is really running** — a live check on the host, not a
  recorded fact: `just baseline` / `just diff-deployed`, or the toplevel
  `outPath` vs `/run/current-system` comparison in
  [`AGENTS.md`](../AGENTS.md)'s State section.
- **Why `nire-cube` doesn't wipe `/root`** —
  `flake/modules/nireHost/cube-configuration.nix` header, and `AGENTS.md`'s
  Safety section.
- **Adding a new host** — skill `new-host-config`
  (`.agents/skills/new-host-config/SKILL.md`).
- **Disk layout (LUKS + btrfs + impermanence)** —
  [`../flake/doc/disko-impermanence-layout.md`](<../flake/doc/disko-impermanence-layout.md>)
  — the generator durandal/tenacity run, the template if cube ever adopts
  impermanence. [disk-formatting.md](disk-formatting.md) is the runbook.
- **Repo-wide layout and the impermanence warning** —
  [`../README.md`](../README.md).

# Hosts & current state

## Contents

- [The hosts](#the-hosts)
- [Where each fact lives](#where-each-fact-lives)

Canonical status lives in [`AGENTS.md`'s State section](../AGENTS.md#state)
— read that directly rather than trusting a count repeated here; it has been
wrong-for-a-day more than once as hosts were added. This page is a map of
where to look for each host.

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

What cube runs, each with its own page — including per-service verification
status and what broke on the way:

- [monitoring](categories/monitoring.md) — Prometheus + Grafana (2026-08-23;
  the Grafana secret-key fix took two rounds — the hand fix regressed).
- [git-forge](categories/git-forge.md) — Forgejo (2026-08-24).
- [reverse-proxy](categories/reverse-proxy.md) — Caddy, the single
  tailnet-facing HTTPS listener with a `tailscaled`-issued cert. Grafana and
  Forgejo are `https://ts-cube.moose-micro.ts.net/grafana/` and `/git/` since
  2026-08-24; the first switch served Forgejo an un-stripped prefix and 404'd
  everything ([lessons-learned.md](lessons-learned.md) #41).
- [landing](categories/landing.md) — glance at `/` (2026-08-24).
- [shortlinks](categories/shortlinks.md) — golink (2026-08-24). Not behind
  Caddy and not a host service: it embeds tsnet and joins the tailnet as its
  own device `go`, needing a one-time interactive login on first start.
- [backup](categories/backup.md) — restic to the QNAP (2026-08-28, issue
  [#87](https://github.com/NireBryce/nixos-configs/issues/87)); local-path
  over NFS failed for real, SFTP since 2026-08-31, still blocked on two sops
  secrets. Runbook: [homelab/backup-runbook.md](homelab/backup-runbook.md).

## Where each fact lives

- **Boot/switch status per host** — [`../AGENTS.md`](../AGENTS.md), State
  section; corrected in place when status changes, nothing else more
  current.
- **Why `nire-cube` doesn't wipe `/root`** —
  `flake/modules/nireHost/cube-configuration.nix` header, and `AGENTS.md`'s
  Safety section.
- **Adding a new host** — skill `new-host-config`
  (`.claude/skills/new-host-config/SKILL.md`).
- **Disk layout (LUKS + btrfs + impermanence)** —
  [`../flake/doc/disko-impermanence-layout.md`](<../flake/doc/disko-impermanence-layout.md>)
  — the generator durandal/tenacity run, the template if cube ever adopts
  impermanence. [disk-formatting.md](disk-formatting.md) is the runbook.
- **Repo-wide layout and the impermanence warning** —
  [`../README.md`](../README.md).

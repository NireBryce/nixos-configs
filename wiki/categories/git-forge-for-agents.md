# `git-forge`, for agents

_Last modified: 2026-09-11_

Condensed from [git-forge.md](git-forge.md), which keeps the reasoning and
the narrative. Facts only here.

Forgejo on `nire-cube`. Added 2026-08-24, nested under `homelab`
2026-08-27. Reached at `https://git.moose-micro.ts.net/` since 2026-09-07;
the old `.../git/` path 404s.

## What's in it

One file, `nixos`-class: `nire/homelab/git-forge/forgejo/forgejo.nix`.

Category isn't named `forgejo` because category-and-module sharing a name
both declare `flake.modules.nixos.forgejo` and silently **merge**. Hit for
real while writing this category.

## Facts

| | |
|---|---|
| Binding | `127.0.0.1:3001` (3000 is Grafana) |
| Firewall | no port opened; the binding is what keeps it off the LAN |
| Database | `sqlite3` (nixpkgs default) |
| Registration | `DISABLE_REGISTRATION = true` |
| Secrets | upstream `forgejo-secrets.service` generates `SECRET_KEY`/`INTERNAL_TOKEN`/`JWT_SECRET` on first run. **Nothing to create by hand.** |
| Persistence | none needed — cube has a persistent root |

## Traps

- **`DOMAIN` and `ROOT_URL` disagree on purpose.** `ROOT_URL` is what a
  browser sees (`https://git.moose-micro.ts.net/`); `DOMAIN` is what SSH
  clone URLs are built from and stays the short `ts-cube`, because git+ssh
  goes through neither Caddy nor Tailscale Serve.
- **Tailscale device names don't match `networking.hostName`** (host
  `nire-cube`, device `ts-cube`). This module set both from the start and
  never hit it.
- **Forgejo's built-in SSH server stays disabled** (`START_SSH_SERVER`
  unset). git+ssh rides the host's own OpenSSH; Forgejo manages
  `~forgejo/.ssh/authorized_keys` itself. Clone URLs are
  `forgejo@ts-cube:...`, port 22. No new port.
- **`forgejo-admin-bootstrap` resets elly's password to the sops value on
  every activation.** A change made through the web UI is silently reverted
  by the next `just switch`. Deliberate, unlike the create-once shape the
  signing-key units use.
- The `forgejo-admin-password` sops secret is declared **in this module**,
  not in `system/secrets/sops.nix`, so it only decrypts on cube.
- **Unauthenticated `/api/v1/users/search` always reports
  `is_admin: false`** regardless of the real value — it cannot settle
  whether an account is admin. Check the Site Administration panel.

## Imported by

`nire-cube` only. Not durandal or tenacity — unasked-for, not a design
limit.

## See also

[git-forge.md](git-forge.md) ·
[../homelab/forgejo.md](../homelab/forgejo.md) (usage) ·
[reverse-proxy.md](reverse-proxy.md) · [monitoring.md](monitoring.md) ·
[git-forge-history.md](git-forge-history.md)

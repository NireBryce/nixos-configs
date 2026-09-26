# `git-forge`, for agents

_Last modified: 2026-09-25_

Condensed from [git-forge.md](git-forge.md), which keeps the reasoning and
the narrative. Facts only here.

Forgejo on `nire-cube`. Added 2026-08-24, nested under `homelab`
2026-08-27. Reached at `https://git.moose-micro.ts.net/` since 2026-09-07;
the old `.../git/` path 404s.

## What's in it

Two files, `nixos`-class, under `config-system/homelab/git-forge/forgejo/`:
`forgejo.nix` (the forge) and `actions-runner.nix` (the CI runner,
2026-09-24).

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
| Actions | `settings.actions.ENABLED = true`; runner in `actions-runner.nix` |

## The runner (added 2026-09-24; in a VM since 2026-09-25; never switched)

The runner is the libvirt guest `forge-runner` on cube —
`virtualization/virtualization-cube.nix` instantiates it, guest config
`hosts/forge-runner-configuration.nix`. cube-side support only in
`git-forge/forgejo/actions-runner.nix`: the sops secret, the registration
oneshot, the token staging. Containment is the point: job code with
docker/podman access roots the VM, not cube.

| | |
|---|---|
| Instance | `services.forgejo-runner.instances.forge-runner` in the GUEST; unit `forgejo-runner-forge\x2drunner.service` |
| Direction | outbound-only worker; dials `https://git.moose-micro.ts.net/` — no port, no tailnet membership; egress enforced by the GUEST's own firewall (gateway DNS/DHCP + forge 443 allowed, private ranges + tailnet dropped, repeated host-side in cube's `mangle` FORWARD; nwfilter attempt abandoned — its drops broke inbound, see virtualization-for-agents) |
| Job→forge | guest `/etc/hosts` pins the FQDN to `192.168.122.1` (virbr0 gw; `vm-networking.nix` opens only 443 + DHCP/DNS there); Caddy TLS → loopback Forgejo; every other `.ts.net` vhost aborts guest-subnet requests (`vmDeny`). 3001 unreachable from the guest, by design |
| Labels | `nix:host` only — jobs run in the VM with guest nix; no container runtime in the guest |
| Secret | sops key `forgejo-runner-secret` (main secrets.yaml, cube-only decryption); staged root:root 0600 into `/var/lib/forgejo-runner-share/` by the registration unit's root `ExecStartPost` |
| Into the guest | virtiofs share (generator `shares` param), `<readonly/>` host-side, mounted at guest `/mnt/runner-secret`; guest runs no sops, no key |
| UUID | pinned literal in the GUEST config; = runner secret's first 16 chars as ASCII bytes (`google/uuid.FromBytes`) |
| Registration | `forgejo-runner-registration.service` on cube re-runs idempotent `forgejo forgejo-cli actions register --secret-file` per activation; `libvirt-vm-forge-runner` ordered After= it |
| Bootstrap | done 2026-09-25 (secret in sops, UUID pinned; guest image + cube toplevel both build). Remains: switch on cube + verify. Original procedure: [../homelab/pending-setup.md](../homelab/pending-setup.md) item 8 |

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
  not in `config-system/secrets/sops.nix`, so it only decrypts on cube.
- **The runner has no `uuid_url` indirection** — runner v13's connection
  schema only knows `url`/`uuid`/`token`/`token_url`; nixpkgs'
  `secrets.*.uuid_url` templating renders a key the runner silently drops
  (the swallowed-key shape). Hence the UUID is a pinned literal, and only
  the token rides `LoadCredential`.
- **Rotating `forgejo-runner-secret` rotates the runner's identity** (UUID
  is derived from it): update the pinned UUID in the GUEST config and
  delete the orphaned old runner row in the admin UI.
- **Unit names escape instance-name dashes**: instance `forge-runner` →
  unit `forgejo-runner-forge\x2drunner.service`. Targeting the plain
  spelling in `systemd.services` silently creates an empty second unit
  (evals clean, does nothing). Caught by reading the rendered unit.
- **Unauthenticated `/api/v1/users/search` always reports
  `is_admin: false`** regardless of the real value — it cannot settle
  whether an account is admin. Check the Site Administration panel.
  `elly` **is** admin (confirmed there 2026-09-12); the endpoint still
  reports otherwise, so don't re-derive the answer from it.

## Imported by

`nire-cube` only. Not durandal or tenacity — unasked-for, not a design
limit.

## See also

[git-forge.md](git-forge.md) ·
[../homelab/forgejo.md](../homelab/forgejo.md) (usage) ·
[reverse-proxy.md](reverse-proxy.md) · [monitoring.md](monitoring.md) ·
[git-forge-history.md](git-forge-history.md)

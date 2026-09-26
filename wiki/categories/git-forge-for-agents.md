# `git-forge`, for agents

_Last modified: 2026-09-26_

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
| Registration | `forge-runner-cycle.service` on cube (root; register runs as the forgejo user): `forgejo-cli actions register --name forge-runner --scope elly --ephemeral --secret-file`, then drop `/run/libvirt-vm/forge-runner.stamp`, restart `libvirt-vm-forge-runner`, wait for `shut off` (destroy after 16200 s), back off 60 s after two consecutive cycles under 120 s; register's UUID output gets an explicit newline (the CLI prints none, so journald held it). Forgejo deletes the runner when its job completes; never-used ones go via `cron.cleanup_offline_runners` (GLOBAL_SCOPE_ONLY=false, 24h). Runner settings `capacity = 1`, `cache.enabled = false`; new repos' Actions unit off (`DEFAULT_REPO_UNITS`) |
| Secrets | upstream `forgejo-secrets.service` generates `SECRET_KEY`/`INTERNAL_TOKEN`/`JWT_SECRET` on first run. **Nothing to create by hand.** |
| Persistence | none needed — cube has a persistent root |
| Actions | `settings.actions.ENABLED = true`; runner in `actions-runner.nix` |

## The runner (added 2026-09-24; in a VM since 2026-09-25; never switched)

The runner is the libvirt guest `forge-runner` on cube —
`virtualization/virtualization-cube.nix` instantiates it, guest config
`hosts/forge-runner-configuration.nix`. cube-side support only in
`git-forge/forgejo/actions-runner.nix`: `forge-runner-cycle`, one fresh
guest and one single-use registration per job. Containment is the point: job code with
docker/podman access roots the VM, not cube.

| | |
|---|---|
| Runner | hand-written `forgejo-runner.service` in the GUEST: `forgejo-runner one-job --wait --url … --uuid <derived> --token-url file:$CREDENTIALS_DIRECTORY/runner-secret --label nix:host`, `SuccessAction`/`FailureAction = poweroff`. Not nixpkgs' `services.forgejo-runner` (daemon mode refuses ephemeral runners; its `config.yaml` connection conflicts with one-job's flags) |
| Direction | outbound-only worker; dials `https://git.moose-micro.ts.net/` — no port, no tailnet membership; egress enforced by the GUEST's own firewall (gateway DHCP + forge 443 allowed, public DNS resolvers, host DNS dropped both sides, private ranges + tailnet dropped, repeated host-side in cube's `mangle` FORWARD; nwfilter attempt abandoned — its drops broke inbound, see virtualization-for-agents) |
| Job→forge | guest `/etc/hosts` pins the FQDN to `192.168.122.1` (virbr0 gw; `vm-networking.nix` opens only 443 + DHCP there); Caddy TLS → loopback Forgejo; every other `.ts.net` vhost aborts guest-subnet requests (`vmDeny`). 3001 unreachable from the guest, by design |
| Labels | `nix:host` only = label `nix`, `host` executor — workflows say `runs-on: nix` (`nix:host` matches nothing, job waits forever); jobs run in the VM with guest nix; no container runtime in the guest |
| Secret | per job: 40 hex from `/dev/urandom` on cube (tmpfs `/run/forge-runner-cycle`), staged root 0600 into `/var/lib/forgejo-runner-share/`, removed when the guest stops. sops `forgejo-runner-secret` is declared but UNUSED since 2026-09-26 (rollback; remove with its secrets.yaml entry) |
| Into the guest | virtiofs share (generator `shares` param), `<readonly/>` host-side, mounted at guest `/mnt/runner-secret`; guest runs no sops, no key |
| UUID | derived in the guest from the staged secret: first 16 chars as ASCII bytes (`google/uuid.FromBytes`), formatted 8-4-4-4-12. New every job |
| Registration | `forgejo-runner-registration.service` on cube re-runs idempotent `forgejo forgejo-cli actions register --scope elly --secret-file` per activation (after `forgejo-admin-bootstrap`; re-registering rewrites owner/repo scope in place); runner settings `capacity = 1`, `cache.enabled = false`; new repos' Actions unit off (`DEFAULT_REPO_UNITS`); `libvirt-vm-forge-runner` ordered After= it |
| Status | live since 2026-09-25; per-job cycle since 2026-09-26. Long-lived-runner era: [git-forge-history.md](git-forge-history.md#the-long-lived-runner-2026-09-24-to-2026-09-26) |

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
- **`one-job` refuses a config that defines a connection** when its own
  `--url`/`--uuid`/`--token-url` are given ("server connection conflict");
  the guest's runner config holds only `runner` and `cache`.
- **Daemon mode refuses ephemeral runners** — ephemeral registration only
  works with `one-job`.
- **A switch never restarts the guest** (`autostart = false`:
  `restartIfChanged = false`, not wanted at boot); guest changes land on
  the next cycle. Changing the cycle script restarts the loop, which
  recreates the guest (kills a running job).
- **`runs-on: nix`, not `nix:host`** — label is `<name>:<executor>`.
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

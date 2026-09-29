# `system`, for agents

_Last modified: 2026-09-29_

Condensed from [system.md](system.md).

`general-config/system/`, 19 subdirectories. Imported whole by every Linux host, **no opt-out for any piece**: anything
that must be optional cannot be filed here (why `virtualization`/`containers` are separate).

## Subdirectories

`base-system-packages/` · `bluetooth/` · `firmware/` · `flatpak/` ·
`font/` · `gaming/` · `home-manager/` · `impermanence/` · `kdeconnect/` ·
`locale-tz-etc/` · `networking/` · `nix-ld/` · `secrets/` · `security/` ·
`sound/` · `ssh/` · `storage/` · `wayland/` · `xdg/`

## The files that matter off-category

| File | Why you'd care |
|---|---|
| `home-manager/enable-home-manager.nix` | *the* NixOS↔HM wiring (`useGlobalPkgs`, `useUserPackages`). Filed here so importing `system` is enough. |
| `home-manager/enable-home-manager-darwin.nix` | the darwin equivalent — what actually brings packages/dotfiles to `lysithea`. Not anything under `macos`. |
| `home-manager/drop-unsupported-packages.nix` | reads `meta.platforms`/`meta.badPlatforms` and drops what darwin can't build, with a warning. **Don't hand-write `lib.mkIf (!pkgs.stdenv.isDarwin)`.** |
| `secrets/sops.nix` | sops-nix, key path derived from the host's own ed25519 SSH host key. `nixos` class only. |
| `secrets/sops-darwin.nix` | points `SOPS_AGE_KEY_FILE` at the Linux-XDG path; darwin's default lookup is `~/Library/Application Support/...`. |
| `secrets/sops-interactive-key.nix` | oneshot, every boot, converts the host ed25519 key to a native age identity. Unconditional (self-heals on hosts that wipe `/root`). Also sets `security.sudo.extraConfig` `env_keep += "EDITOR VISUAL"` (sudo's `env_reset` strips `environment.variables.EDITOR` before `sudo sops`). |
| `secrets/low-side/secrets.yaml` | not a module — `.sops.yaml`-only, keyed to a personal SSH key instead of a host key, no `sops.secrets.*`, no NixOS activation. Skill `low-side-secrets`. |
| `impermanence/declare-persistence-option.nix` | **not** the [impermanence](impermanence.md) category. Declares the option unconditionally, even where nothing populates it. |
| `security/sudo-wheel-only.nix` | sets `security.sudo.execWheelOnly` — `sudo` executable by wheel-group members only. |
| `storage/smartd.nix` | smartmontools + scheduled S.M.A.R.T. self-tests — disk wear/failure monitoring on every host. |

## Traps

- **"virtualization" here means VMs only** ([virtualization](virtualization.md),
  libvirt/QEMU). Podman/distrobox is [containers](containers.md), moved out
  2026-08-22.
- **`*-persist.nix` is a sibling-file convention**, not centralized under
  `impermanence`: `networking/tailscale-persist.nix`
  (`/var/lib/tailscale/tailscaled.state`),
  `networking/networkmanager-persist.nix`
  (`/var/lib/NetworkManager/secret_key`),
  `networking/mullvad-persist.nix` (`/etc/mullvad-vpn`). All rely on
  `environment.persistence."/persist".directories` being `listOf` and
  concatenating across files.
- **`environment.persistence` refuses to bind-mount over a live file.**
  Move the existing file into `/persist` first, then re-switch.
- **Tailscale device names don't match `networking.hostName`**, a tailnet
  ACL can block peer traffic with every local firewall setting correct, and
  a name that won't resolve at all means check Tailscale on the machine
  you're running *from*. Mechanism: `networking/tailscale.nix` header; `just reach <host>` tries real names.
- `.sops.yaml` enrollment is tracked separately from importing these modules:
  [../impermanence-and-secrets.md](../impermanence-and-secrets.md).
- **`.sops.yaml`'s `creation_rules` `path` isn't `^`-anchored** — a Go
  regexp, so `./secrets.yaml$` also matches the tail of any nested path
  ending in `/secrets.yaml` (e.g. `low-side/secrets.yaml`). sops takes the
  first matching rule: list a nested file's specific rule before the
  general one, or it silently encrypts for the general rule's (wrong)
  recipients. Skill `low-side-secrets`.

## Useful

`systemctl show firewall.service -p ExecStart` reads as a plain shell
script (world-readable, no root) and is the literal in-order `iptables`
ruleset NixOS applied at boot.

## Imported by

All three NixOS hosts, whole. `lysithea` imports it too, but only for
`enable-home-manager-darwin.nix` — the rest of the category declares no
`darwin`-class modules, so nothing else comes with it. The
`homeManager`-class slice (`font`, `drop-unsupported-packages`) reaches
every host via `ellyHomeManager`, not via this import.

## See also

[system.md](system.md) · [impermanence.md](impermanence.md) ·
[virtualization.md](virtualization.md) · [containers.md](containers.md) ·
[../architecture.md](../architecture.md)

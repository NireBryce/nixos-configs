# `system` — `nire/system/`

The largest category by far — 37 files across 19 subdirectories — and the
one every Linux host in this repo imports whole, with no way to opt out of
any piece of it. That property is exactly why
[virtualization](virtualization.md) and [containers](containers.md) got
split into their own categories instead of living here: anything that needs
to be optional for some hosts (or just optional in principle) can't be filed
under `system`.

## Subdirectories at a glance

| Subdirectory | Files | What it is |
|---|---|---|
| `base-system-packages/` | 4 | `core-utilities`, `fallback-editors`, `performance`, `sensors` — baseline `environment.systemPackages` every host wants. |
| `bluetooth/` | 1 | `bluetooth.nix`. |
| `firmware/` | 2 | `firmware-all.nix`, `fwupd.nix`. |
| `flatpak/` | 1 | `flatpak.nix`. |
| `font/` | 1 | `font.nix` — reaches every host via `ellyHomeManager`, see below. |
| `gaming/` | 3 | `gaming.nix`, `sunshine.nix`, `sunshine-elly.nix`. |
| `home-manager/` | 3 | The NixOS↔Home Manager wiring itself. See below. |
| `impermanence/` | 1 | `declare-persistence-option.nix` — **not** the [impermanence](impermanence.md) category; see that page's "don't confuse the two" section. |
| `kdeconnect/` | 1 | `kde-connect.nix`. |
| `locale-tz-etc/` | 2 | `locale.nix`, `tz.nix`. |
| `networking/` | 8 | tailscale, vpn, wifi, avahi, base `networking.nix`, `resolved.nix`, and two `*-persist.nix` siblings. See below — MagicDNS naming and the ACL trap especially. |
| `nix-ld/` | 1 | `nix-ld.nix`. |
| `secrets/` | 1 | `sops.nix` — sops-nix wiring. See below. |
| `security/` | 1 | `yubikey.nix`. |
| `sound/` | 1 | `pipewire.nix`. |
| `ssh/` | 1 | `ssh.nix`. |
| `storage/` | 2 | `coredump-limit.nix`, `storage-NFS.nix`. |
| `wayland/` | 1 | `wayland.nix`. |
| `xdg/` | 2 | `xdg.nix`, `xdg-portals.nix`. |

## Home Manager integration lives here

`home-manager/enable-home-manager.nix` is *the* module that wires
`home-manager.users.elly` to the shared `ellyHomeManager` bundle with
`useGlobalPkgs`/`useUserPackages` — see
[../architecture.md](../architecture.md). It's filed under `nire/system/`
specifically so the `system` category picks it up and every host that
imports `system` gets it automatically, rather than each host wiring HM in
by hand. `enable-home-manager-darwin.nix` is the nix-darwin-side equivalent
for `lysithea` — it's what actually brings packages and dotfiles to a darwin
host, not anything under [macos](macos.md).

`home-manager/drop-unsupported-packages.nix` is the platform-support
counterpart: `ellyHomeManager` is shared verbatim across all five hosts, so
every package in it has to survive `aarch64-darwin`. Eleven packages didn't
(`vlc`, `gimp`, `libreoffice-qt`, `github-desktop`, `piper`, `qpwgraph`,
`strace`, `ltrace`, `iotop`, `sysstat`, `ethtool`), each previously guarded
by a hand-written `lib.mkIf (!pkgs.stdenv.isDarwin)` — a fact about the
package restated by hand in config, which is exactly the shape that
eventually disagrees with reality. This file reads `meta.platforms`/
`meta.badPlatforms` instead and drops what can't build, once, with a warning
naming what it dropped — see the `nirepackages-platform-support` skill for
the full build-support-vs-Homebrew-overlap distinction this is one half of.

## Secrets

`secrets/sops.nix` wires in `inputs.sops-nix.nixosModules.sops`, deriving
the decryption key path from the host's own ed25519 SSH host key
(`config.services.openssh.hostKeys`) rather than a hardcoded path. See
[../impermanence-and-secrets.md](../impermanence-and-secrets.md) for which
hosts are actually enrolled in `.sops.yaml` — that's tracked separately from
which hosts import this module.

## Containers vs. virtualization — the live trap, and no longer filed here

Podman and distrobox — OCI containers — used to live under
`system/containers/`, but moved out entirely 2026-08-22 into their own
category: see [containers](containers.md). This section stays as a pointer
because the trap is still live and this is where someone remembering the old
location will look first: the word "virtualization" means only
[the VM category](virtualization.md) (libvirt/QEMU) — the containers module
was briefly named `virtualization.nix` itself, until 2026-08-21, before that
name was needed for the actual VM category — and a memory of "virtualization
is the podman one" is exactly backwards no matter which of the module's three
names and two directories you're picturing.

## The `*-persist.nix` sibling-file convention

`networking/tailscale-persist.nix` and `networking/networkmanager-persist.nix`
are the `system`-category examples of a convention that recurs across
several categories: persistence for state that matters to one specific
thing is filed as a sibling of the module that generates it, not
centralized under [impermanence](impermanence.md).

- **`tailscale-persist.nix`** persists `/var/lib/tailscale/tailscaled.state`
  — without it, Tailscale needs re-authenticating on every boot, since node
  identity lives under `/var/lib` and both hosts that import this roll `/`
  back on every boot.
- **`networkmanager-persist.nix`** persists
  `/var/lib/NetworkManager/secret_key` — the key that encrypts
  NetworkManager's stored connection secrets. `/etc/NetworkManager/system-connections`
  itself was already persisted via `WARN-impermanence.nix`'s directory list,
  but the *key* that encrypts what's in it wasn't, so every boot generated a
  fresh key while the encrypted secrets alongside it stayed keyed to the
  previous one. Found 2026-08-22 via `root-drift.sh` flagging `secret_key`
  as real, non-cosmetic drift — the same pass that found
  [virtualization](virtualization.md)'s `libvirt-persist.nix` gap.

Both rely on `environment.persistence."/persist".directories` being
`listOf` and therefore concatenating across every file that appends to it —
same merge behavior as `environment.systemPackages` and the same one that
makes `home.file.<n>.text` a trap on the Home Manager side (see
[shell-config](shell-config/README.md)). See
`nire/system/impermanence/declare-persistence-option.nix`'s own header (and
[impermanence](impermanence.md)) for why that option has to be declared
unconditionally even on hosts where nothing populates it.

## Tailscale: MagicDNS names, and the ACL lives outside this repo

`networking/resolved.nix` + `networking/avahi.nix` (added 2026-08-21, split
DNS between the two — avahi owns `.local`, resolved owns unicast DNS and
Tailscale's split-DNS) were runtime-verified on `nire-tenacity` 2026-08-22:
`getent`/`ping`/`ssh` all resolve peers by MagicDNS name correctly. Two traps
turned up doing that verification, both real, neither a bug in this repo —
recorded in full in `networking/tailscale.nix`'s own header:

- **Tailscale device names don't match `networking.hostName`.** `nire-cube`
  the NixOS host is `ts-cube` on the tailnet; same `ts-` pattern fleet-wide.
  Looks exactly like a DNS failure until you check `tailscale status` for
  the name a device actually registered.
- **A tailnet ACL can silently block all peer-to-peer traffic while every
  local NixOS firewall setting is correct**, and it looks exactly like a
  host firewall problem right up until you check the admin console. The
  fault hit here: a "match everything" access rule whose `dst` was
  `autogroup:internet` (grants exit-node/internet access only) instead of
  `autogroup:members` — the rule's own comment said "match absolutely
  everything," and it didn't. `networking.firewall.trustedInterfaces =
  [ "tailscale0" ]` (`networking.nix`) is provably not the cause in that
  scenario — the ACL lives entirely in Tailscale's admin console, outside
  this repo and outside anything `just switch` touches.

Also worth keeping: `systemctl show firewall.service -p ExecStart`, read as
a plain shell script (world-readable, no root needed), is the literal
in-order `iptables` ruleset NixOS applied at boot — faster than querying the
live table when the question is "is `trustedInterfaces` really the first
rule in the chain."

## Imported by

All four NixOS hosts import `system` whole. `lysithea` imports it too — for
`enable-home-manager-darwin.nix`, per that file's own comment "this is what
brings packages and dotfiles in" — but only the `nixos`/`darwin`-class
subset that actually declares a `darwin` class reaches it; `bluetooth`,
`networking`, `kdeconnect`, and most of the rest of this category simply
don't declare `darwin`-class modules, so importing `system` on lysithea
doesn't drag any of that in. The `homeManager`-class slice
(`font`, `drop-unsupported-packages`) reaches every host, lysithea included,
via `ellyHomeManager` rather than through this category import at all.

## See also

- [impermanence](impermanence.md) — `declare-persistence-option.nix`, and
  the "don't confuse the two `impermanence`s" note.
- [virtualization](virtualization.md) and [containers](containers.md) — both
  split out of `system` so hosts could opt out (or, for containers, could in
  principle); easy to confuse the two by history and by name.
- [../architecture.md](../architecture.md) — the Home Manager integration
  and platform-support mechanisms this category's `home-manager/` files
  implement.

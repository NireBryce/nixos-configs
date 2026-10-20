# `system` — `general-config/system/`

_Last modified: 2026-10-20_

The largest category: 15 subdirectories (no per-file count here; see
categories/00-INDEX.md's Index section for why). Every Linux host imports it
whole, with no way to opt out of any piece. That is why
[virtualization](virtualization.md) and [containers](containers.md) are their
own categories: anything that needs to be optional for some hosts, even in
principle, can't be filed under `system`.

> **Condensed version:**
> [system-for-agents.md](system-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [Subdirectories](#subdirectories)
- [Home Manager integration lives here](#home-manager-integration-lives-here)
- [Secrets](#secrets)
- [Containers vs. virtualization — the live trap, and no longer filed here](#containers-vs-virtualization--the-live-trap-and-no-longer-filed-here)
- [The `*-persist.nix` sibling-file convention](#the--persistnix-sibling-file-convention)
- [Tailscale: MagicDNS names, and the ACL lives outside this repo](#tailscale-magicdns-names-and-the-acl-lives-outside-this-repo)
- [System diagram (nix-topology)](#system-diagram-nix-topology)
- [Imported by](#imported-by)
- [See also](#see-also)

## Subdirectories

Most are what their names say; the full list is on
[system-for-agents.md](system-for-agents.md), alongside that page's table
of the files that matter off-category. Four repay reading before reaching
into them, and each has its own section below:

- **`home-manager/`** — the NixOS↔Home Manager wiring itself, not user
  dotfiles ([below](#home-manager-integration-lives-here)).
- **`secrets/`** — three sops modules for three different problems, plus
  `low-side/`, which is not a module at all ([below](#secrets)).
- **`networking/`** — tailscale, vpn, wifi, the resolved/avahi split, and
  three `*-persist.nix` sibling files
  ([below](#tailscale-magicdns-names-and-the-acl-lives-outside-this-repo)).
- **`impermanence/`** — **not** the [impermanence](impermanence.md)
  category: it only declares the persistence option. That page's "don't
  confuse the two" section has the full note.

## Home Manager integration lives here

`home-manager/enable-home-manager.nix` is *the* module that wires
`home-manager.users.elly` to the shared `elly-home-manager` bundle with
`useGlobalPkgs`/`useUserPackages` — see
[../architecture.md](../architecture.md). It's filed under `general-config/system/`
specifically so the `system` category picks it up and every host that
imports `system` gets it automatically, rather than each host wiring HM in
by hand. `enable-home-manager-darwin.nix` is the nix-darwin-side equivalent
for `lysithea` — it's what brings packages and dotfiles to a darwin
host, not anything under [macos](macos.md).

`home-manager/drop-unsupported-packages.nix` is the platform-support
counterpart: `elly-home-manager` is shared verbatim across all four hosts, so
every package in it has to survive `aarch64-darwin`. Eleven didn't (`vlc`,
`gimp`, `libreoffice-qt`, `github-desktop`, `piper`, `qpwgraph`, `strace`,
`ltrace` (since removed), `iotop`, `sysstat`, `ethtool`), each previously
guarded by a hand-written `lib.mkIf (!pkgs.stdenv.isDarwin)` — a restated fact that can
drift. This file reads `meta.platforms`/`meta.badPlatforms` and drops what
can't build, once, with a warning naming what it dropped. See skill
`package-platform-support` for the full
build-support-vs-Homebrew-overlap distinction this is one half of.

## Secrets

`secrets/sops.nix` wires in `inputs.sops-nix.nixosModules.sops`, deriving
the decryption key path from the host's own ed25519 SSH host key
(`config.services.openssh.hostKeys`) rather than a hardcoded path. It's
`flake.modules.nixos` only — nothing on darwin currently consumes
`sops.secrets.*` at activation, so there was nothing to wire there.

`secrets/sops-darwin.nix` (2026-08-29) fixes a narrower, separate problem:
sops's default identity-file lookup is platform-dependent (Linux checks
`~/.config/sops/age/keys.txt`, darwin checks `~/Library/Application
Support/sops/age/keys.txt` instead), so a key sitting at the Linux-XDG path
is invisible to a plain `sops` invocation on macOS even with a correctly
enrolled `.sops.yaml` entry and a correctly re-encrypted `secrets.yaml`. This
module points `SOPS_AGE_KEY_FILE` at the Linux-XDG path directly via
`environment.variables`, Nix-interpolated off `config.users.users.elly.home`
rather than left for the shell to expand at sourcing time.

`secrets/sops-interactive-key.nix` (2026-08-29) fixes a third, NixOS-side
problem found chasing this on `nire-cube`: sops's
`SOPS_AGE_SSH_PRIVATE_KEY_FILE` path failed to match a host's own enrolled
key against its own correctly-encrypted `secrets.yaml` block, despite the
key being independently verified correct three ways — a real quirk in
sops's SSH-key conversion, not a config problem. A oneshot run
unconditionally every boot converts the host's ed25519 key to a native age
identity at the Linux default location. Unconditional (contrast
`grafana-secret-key-setup.service`'s create-if-missing) is deliberate: a
pure derivation of an existing key, self-healing because durandal/tenacity
wipe `/root` every boot. See the module header for the nix-store-safety
reasoning.

The same module also fixes which editor `sudo sops secrets.yaml` opens.
Setting `environment.variables.EDITOR = "micro"` system-wide was not
sufficient on its own — confirmed 2026-09-16, `sudo sops` still opened
vi/vim despite it — because `sudo`'s default `env_reset` discards the
invoking environment (including EDITOR/VISUAL) before exec, and that reset
happens independently of a target-user shell ever sourcing
`environment.variables`. The fix is `security.sudo.extraConfig = ''Defaults
env_keep += "EDITOR VISUAL"'';`, which makes sudo pass the invoking user's
own EDITOR through instead of resetting it away.

See [../impermanence-and-secrets.md](../impermanence-and-secrets.md) for
which hosts are enrolled in `.sops.yaml` — that's tracked separately
from which hosts import these modules.

`secrets/low-side/` (2026-09-17) is not a fourth module and declares no
`sops.secrets.*` — it's `.sops.yaml`-only, a file keyed to a personal SSH
key instead of a host key, for secrets that don't need NixOS activation at
all. Skill `low-side-secrets` has the pattern and its two sharp edges.

## Containers vs. virtualization — the live trap, and no longer filed here

Podman and distrobox — OCI containers — moved out of `nire/system/containers/`
2026-08-22 into their own category: see [containers](containers.md). This
pointer stays because the trap is live and this is where someone remembering
the old location will look: "virtualization" means only
[the VM category](virtualization.md) (libvirt/QEMU) — the containers module
was itself briefly named `virtualization.nix` until 2026-08-21 — so a
memory of "virtualization is the podman one" is exactly backwards no matter
which of the module's three names you're picturing.

## The `*-persist.nix` sibling-file convention

`networking/tailscale-persist.nix`, `networking/networkmanager-persist.nix`
and `networking/mullvad-persist.nix` are the `system`-category examples of a convention that recurs across
several categories: persistence for state that matters to one specific
thing is filed as a sibling of the module that generates it, not
centralized under [impermanence](impermanence.md).

- **`tailscale-persist.nix`** persists `/var/lib/tailscale/tailscaled.state`
  — without it, Tailscale needs re-authenticating on every boot, since node
  identity lives under `/var/lib` and both hosts that import this roll `/`
  back on every boot.
- **`mullvad-persist.nix`** persists `/etc/mullvad-vpn` (account, device,
  settings) — without it the Mullvad daemon (`vpn.nix`, enabled 2026-09-26)
  logs out and registers a new device on every boot.
- **`networkmanager-persist.nix`** persists
  `/var/lib/NetworkManager/secret_key` — the key encrypting NetworkManager's
  stored connection secrets. `/etc/NetworkManager/system-connections` was
  already persisted via `WARN-impermanence.nix`'s directory list, but the
  *key* wasn't — every boot generated a fresh key while the encrypted
  secrets stayed keyed to the previous one. Found 2026-08-22 via
  `root-drift.sh`, the same pass that found
  [virtualization](virtualization.md)'s gap. First activation (tenacity,
  2026-08-26) hit impermanence's own guard — NetworkManager had generated a
  live `secret_key` before the persistence entry ran, and
  `environment.persistence` refuses to bind-mount over a live file. Fixed by
  moving the live key into `/persist` before re-switching; confirmed by
  matching inode and unchanged mtime. Full detail in the module's history
  note.

Both rely on `environment.persistence."/persist".directories` being
`listOf` and therefore concatenating across every file that appends to it —
same merge behavior as `environment.systemPackages` and the same one that
makes `home.file.<n>.text` a trap on the Home Manager side (see
[shell-config](shell-config/00-INDEX.md)). See
`general-config/system/impermanence/declare-persistence-option.nix`'s own header (and
[impermanence](impermanence.md)) for why that option has to be declared
unconditionally even on hosts where nothing populates it.

## Tailscale: MagicDNS names, and the ACL lives outside this repo

`networking/resolved.nix` + `networking/avahi.nix` (added 2026-08-21, split
DNS between the two — avahi owns `.local`, resolved owns unicast DNS and
Tailscale's split-DNS) were runtime-verified on `nire-tenacity` 2026-08-22:
`getent`/`ping`/`ssh` all resolve peers by MagicDNS name correctly.

Three traps have turned up reaching a host by name since, none a bug in
this repo — full mechanism, dates, and the actual fixes for all three live
in `networking/tailscale.nix`'s own header, not repeated here:

- Tailscale device names don't match `networking.hostName`.
- A tailnet ACL can silently block peer-to-peer traffic while every local
  firewall setting is correct — fixed in the admin console, not here.
- A tailnet name that won't resolve *at all* means check Tailscale on the
  machine you're running *from*, not the name — `just reach <host>`
  (`flake/scripts/reach-host.sh`) tries a host's real names automatically
  instead. See [../traps-and-skills.md](../traps-and-skills.md).

Also worth keeping: `systemctl show firewall.service -p ExecStart`, read as
a plain shell script (world-readable, no root needed), is the literal
in-order `iptables` ruleset NixOS applied at boot — faster than querying the
live table when the question is "is `trustedInterfaces` really the first
rule in the chain."

## System diagram (nix-topology)

`networking/nix-topology.nix` wires [nix-topology](https://github.com/oddlama/nix-topology)
in, so the fleet can be rendered as SVG straight from the NixOS configs:

```sh
nix build .#topology.x86_64-linux.config.output
```

The result holds `main.svg` (services per host) and `network.svg` (networks
and links). The NixOS half of the module is imported by every host that takes
the `system` category; the flake-parts half adds the `topology` output.

What the hand-written global topology (`perSystem.topology.modules` in that
file) declares is limited to what this repo already states: the host roster,
the `ts-<x>` naming rule and the backup target `ts-hive`, all on one
`tailnet` network. It deliberately carries no subnets, addresses or upstream
devices. `forge-runner` is a guest, not a machine, and does not import the
module, so it is not drawn; `nire-lysithea` is a darwin host and is declared
by hand.

The rendered SVGs are build output and are not committed. The restic
extractor's list of backed-up paths is deliberately left off the diagram (the
module hides the extracted service and declares one with the name and
repository only).

## Imported by

All three NixOS hosts import `system` whole. `lysithea` imports it too — for
`enable-home-manager-darwin.nix`, per that file's own comment "this is what
brings packages and dotfiles in" — but only the `nixos`/`darwin`-class
subset that declares a `darwin` class reaches it;
`networking`, `kdeconnect`, and most of the rest of this category
don't declare `darwin`-class modules, so importing `system` on lysithea
doesn't drag any of that in. The `homeManager`-class slice
(`font`, `drop-unsupported-packages`) reaches every host, lysithea included,
via `elly-home-manager` rather than through this category import at all.

## See also

- [impermanence](impermanence.md) — `declare-persistence-option.nix`, and
  the "don't confuse the two `impermanence`s" note.
- [virtualization](virtualization.md) and [containers](containers.md) — both
  split out of `system` so hosts could opt out (or, for containers, could in
  principle); easy to confuse the two by history and by name.
- [../architecture.md](../architecture.md) — the Home Manager integration
  and platform-support mechanisms this category's `home-manager/` files
  implement.
- [monitoring](monitoring.md) — Grafana on `nire-cube` reuses this
  category's `trustedInterfaces = [ "tailscale0" ]` firewall rule rather
  than opening a new port, the same mechanism the Tailscale section above
  documents.

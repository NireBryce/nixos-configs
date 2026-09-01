# `macos` — `nire/macos/`

## Contents

- [What's in it](#whats-in-it)
- [Sharp corner: a Homebrew-updated system extension can get stuck mid-upgrade](#sharp-corner-a-homebrew-updated-system-extension-can-get-stuck-mid-upgrade)
- [Why `hardware`/`desktop-env`/`peripherals` are absent from lysithea instead of guarded here](#why-hardwaredesktop-envperipherals-are-absent-from-lysithea-instead-of-guarded-here)
- [Imported by](#imported-by)
- [See also](#see-also)

`darwin`-class only, throughout — the one category in this repo that is
entirely platform-specific rather than shared-with-a-guard. See
[../architecture.md](../architecture.md)'s "Platform support is derived"
section for the general pattern this fits into.

## What's in it

- **`homebrew/homebrew.nix`** — casks and formulae for what nix doesn't
  package well on Aarch64, or what needs App Store / notarisation / menu-bar
  integration a nix-built `.app` doesn't get for free. Ported near-verbatim
  from a since-abandoned standalone flake (`macos-old/nire-lysithea-configuration.nix`)
  that predates this repo's current structure — TODOs and all, kept
  deliberately rather than cleaned up, because they're honest information
  about which casks nobody remembers the purpose of anymore, not noise.
- **`shells/shells.nix`** — system-level shell registration only (`/etc/shells`,
  stopping the system's own zsh completion setup from fighting Home
  Manager's). zsh itself is configured through Home Manager, same as the
  Linux hosts — see [shell-config](shell-config/README.md).
- **`system-settings/darwin-system.nix`** — `system.primaryUser = "elly"`
  (hardcoded, same as `users.users.elly` and `home.username` everywhere else
  in this tree — nix-darwin needs it for homebrew and launchd
  user-context activation) and `nix.enable = true` (nix-darwin manages the
  nix installation itself rather than assuming an external installer like
  Determinate owns it).

## Sharp corner: a Homebrew-updated system extension can get stuck mid-upgrade

Found 2026-08-31 on `nire-lysithea` diagnosing "the Tailscale service won't
install". Not a bug in this repo — `tailscale.nix`
(`nire/system/networking/`) is `flake.modules.nixos`-only and never reaches
darwin; on lysithea, Tailscale is entirely the `tailscale-app` cask in
`homebrew.nix`, unmanaged by Nix past that one line.

`systemextensionsctl list` showed two entries for the same extension at once:

```
io.tailscale.ipn.macsys.network-extension (1.98.9/101.98.9)   [terminating for uninstall]
io.tailscale.ipn.macsys.network-extension (1.102.3/101.102.3) [activated waiting to upgrade]
```

macOS system-extension upgrades are transactional: the old extension has to
fully unload before the new one activates, and that hand-off needs a reboot
(or at least a full logout) to complete — Homebrew silently auto-updating the
cask in the background does not trigger one. The machine had been up 4 days
with no reboot since the update landed, so `sysextd` sat on the half-finished
transaction the whole time. While stuck like this, any further
install/upgrade of the extension looks like it "won't install" — `sysextd`
already has a pending transaction outstanding and won't start another.
`tailscaled` itself kept running and `tailscale status` still resolved peers
fine in this state (apparently still riding the old, not-yet-unloaded
extension), so connectivity can look fine right up until it doesn't.

Fix is just a reboot — nothing to change in this repo, and no SIP-disabling
`systemextensionsctl reset` needed. After reboot, `systemextensionsctl list`
should show exactly one entry for the extension, `[activated enabled]`.

Separately noticed in the same session, unrelated to the stuck extension: the
tailnet listed this machine twice — `nire-lysithea` (online, the live node)
and `ts-lysithea` (offline, stale) — a leftover from a past re-registration
that doesn't match the fleet's `ts-<host>` MagicDNS naming
([system](system.md)'s Tailscale section). Worth pruning `ts-lysithea` from
the tailnet admin console; not a Nix-config issue either.

## Why `hardware`/`desktop-env`/`peripherals` are absent from lysithea instead of guarded here

Nothing in `macos/` guards against being imported on Linux, because nothing
Linux-specific ever tries to import it — `lysithea-configuration.nix`
simply doesn't list `hardware`, `desktop-env`, or `peripherals` at all,
since none of those categories declare a `darwin` class and importing them
would resolve to empty aggregates. Left out rather than imported-for-nothing.
This is the mirror image of `drop-unsupported-packages.nix`'s job on the
Home Manager side (see [system](system.md)) — there, one shared package list
needs filtering per-platform at evaluation time; here, whole categories are
just never asked for in the first place.

## Imported by

`nire-lysithea` only — the sole darwin host.

## See also

- [nix](nix.md) — `basic-nix-settings.nix` also has a `darwin`-class block,
  the other place platform-specific nix settings live.
- [shell-config](shell-config/README.md) — where zsh/bash themselves are actually
  configured.
- The `nirepackages-platform-support` skill
  (`.claude/skills/nirepackages-platform-support/SKILL.md`) — the
  build-support-vs-Homebrew-overlap distinction that governs everything in
  `ellyHomeManager`, separate from this category.

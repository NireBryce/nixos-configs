# `macos` — `nire/macos/`

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
  Linux hosts — see [shell-config](shell-config.md).
- **`system-settings/darwin-system.nix`** — `system.primaryUser = "elly"`
  (hardcoded, same as `users.users.elly` and `home.username` everywhere else
  in this tree — nix-darwin needs it for homebrew and launchd
  user-context activation) and `nix.enable = true` (nix-darwin manages the
  nix installation itself rather than assuming an external installer like
  Determinate owns it).

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
- [shell-config](shell-config.md) — where zsh/bash themselves are actually
  configured.
- The `nirepackages-platform-support` skill
  (`.claude/skills/nirepackages-platform-support/SKILL.md`) — the
  build-support-vs-Homebrew-overlap distinction that governs everything in
  `ellyHomeManager`, separate from this category.

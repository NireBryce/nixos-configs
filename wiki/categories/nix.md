# `nix` — `nire/nix/`

## What's in it

- **`nix-settings/basic-nix-settings.nix`** — the one file in this whole
  repo that declares all three classes deliberately, each slightly
  different, and explains why each differs:
  - `homeManager` — nearly empty. `nixpkgs.config` **cannot** be set from
    Home Manager here: HM is NixOS-managed with `useGlobalPkgs`, which makes
    it *reject* every `nixpkgs.*` option outright rather than silently
    ignore it. `allowUnfree` therefore has to come from the `nixos` block
    below instead, applying to the same shared `pkgs` instance. This also
    means the old `allowUnfreePredicate = (_: true)` workaround for
    upstream Home Manager issue #2942 is gone — if unfree packages start
    failing in home config, that block is the first thing to check.
  - `nixos` — `nix.nixPath`, `nix.settings.trusted-users`/
    `experimental-features`, `nix.channel.enable = false` (paired with
    fixes for `comma` and `nix-index` not wanting channel-based lookups),
    and `nixpkgs.config.allowUnfree = true`.
  - `darwin` — the same shape minus `nix.channel.enable`, left out rather
    than guessed at because it isn't confirmed to exist on nix-darwin, and
    channel management matters less on a machine nobody points at
    nixos-unstable by habit.
- **`manconfig/manconfig.nix`** — `homeManager`-only. An `apropos`/`man -k`
  index. Neither built-in option fits: `programs.man.generateCaches` builds
  a `buildEnv` over every `home.packages` entry and reruns `mandb` at
  *build* time, so touching any one of ~126 packages rebuilds the whole
  index; `documentation.man.generateCaches` is system-scoped and would miss
  `/etc/profiles/per-user/<user>/share/man`, where the packages actually
  worth searching live. Was on only as a side effect of fish's
  `generateCompletions` setting it, and stayed on when fish did.

## Imported by

All five hosts. The four NixOS hosts import `nix` directly in their own
category list; `lysithea` imports it too, under its `darwin`-class list —
which works precisely because `basic-nix-settings.nix` declares a real
`darwin` block, unlike most modules in this tree. `manconfig.nix` (homeManager-only)
reaches every host, lysithea included, via the shared `ellyHomeManager`
bundle (`nireUser/elly-home-manager.nix`) rather than through any host's own
category imports — see [../architecture.md](../architecture.md).

## See also

- [macos](macos.md) — the other place platform-specific nix/darwin settings
  live, and the `darwin.primaryUser`/`nix.enable` split with this file.
- [system](system.md) — `home-manager/drop-unsupported-packages.nix`, the
  package-level counterpart to this file's platform-conditional settings.

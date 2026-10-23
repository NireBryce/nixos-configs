# Durandal: gaming setup

_Last modified: 2026-10-22_

What `nire-durandal` runs games with, and where each piece is configured.
The shared Steam setup reaches every NixOS host that imports `system`. The
Heroic and GameMode setup is durandal's own, added 2026-10-22 for Alan Wake 2,
which is an Epic Games Store title. As of that date the change
*evaluates*, passes `just preflight`, and resolves a dry-run build plan. It
has not been built or switched on durandal; check with `just diff-deployed`
on the host.

## Contents

- [Hardware](#hardware)
- [Where the config lives](#where-the-config-lives)
- [Heroic](#heroic)
- [GameMode](#gamemode)
- [Alan Wake 2](#alan-wake-2)
- [Worth considering](#worth-considering)

## Hardware

Read from the host on 2026-10-22 (`lspci`, `/proc/cpuinfo`, `free`):

| Part | Value |
|---|---|
| CPU | AMD Ryzen 7 5800X (8 cores) |
| GPU | AMD Radeon RX 6700 XT, Navi 22 / RDNA2, `1002:73df`, DRM `card1` |
| RAM | 32 GB |

The GPU driver comes from the `hardware` category's `amdgpu.nix` (Mesa with
32-bit support, RADV Vulkan). See [categories/hardware.md](categories/hardware.md).

## Where the config lives

| File | Hosts | What it adds |
|---|---|---|
| `flake/modules/general-config/system/gaming/gaming.nix` | every host importing `system` | Steam (gamescope session, protontricks, Remote Play firewall), MangoHud, protonup-qt, SteamTinkerLaunch |
| `flake/modules/host-config/durandal/configuration/gaming-durandal.nix` | durandal only | Heroic with gamescope and gamemode inside its FHS env; `programs.gamemode`; the user account in the `gamemode` group |
| `flake/modules/host-config/durandal/configuration/planetside2-ports-durandal.nix` | durandal only | Planetside 2's UDP ports |

The Heroic and GameMode settings are a host module rather than part of
`gaming.nix`, so tenacity (Jovian's session, its own decky-loader gamemode)
does not change with them. Tenacity's toplevel drvPath was identical
before and after the change.

## Heroic

The nixpkgs `heroic` package runs games inside a bubblewrap FHS environment
that leaves out gamemode and gamescope
([NixOS wiki](https://wiki.nixos.org/wiki/Heroic_Games_Launcher)). Without
them in the environment, Heroic's per-game GameMode and gamescope toggles
find nothing. The module therefore installs
`heroic.override { extraPkgs = … [ gamescope gamemode ]; }`.

- Wine and GE-Proton builds come from Heroic's own Wine Manager, not from
  nixpkgs.
- Heroic's settings and installed games live under `/home`, which is its own
  btrfs subvolume, so the `/root` wipe on boot does not touch them
  ([impermanence-and-secrets.md](impermanence-and-secrets.md)).
- Gamescope inside Heroic is set per game, as a wrapper command in the
  game's settings. The Heroic wiki notes that gamescope can fail when
  MangoHud or GameMode is also on, so test with those off first
  ([Heroic wiki](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/wiki/How-To:-Other-Tools-and-Wrappers-%28gamescope%29)).

## GameMode

`programs.gamemode.enable = true`, with `settings.general.renice = 10`.
While a game holds it, `gamemoded` raises the game's priority and switches
the CPU governor to `performance`.

- `enableRenice` is left at its default (`true`), so nixpkgs installs a
  `gamemoded` security wrapper with `cap_sys_nice+ep`.
- gamemode ships a polkit rule that lets members of the `gamemode` group run
  its four helpers without authentication: `cpugovctl` (CPU governor),
  `cpucorectl` (core parking), `gpuclockctl` (GPU
  `power_dpm_force_performance_level`), and `procsysctl`. `procsysctl`
  accepts only `split_lock_mitigate`. The user account is in that group, so
  no password prompt appears when a game starts.
- GPU optimisations (the `[gpu]` section) are not enabled, so `gpuclockctl`
  is never called.

To use it: turn on GameMode in Heroic's per-game settings, or for Steam
set the launch options to `gamemoderun %command%`. Check it is active with
`gamemoded -s`.

## Alan Wake 2

What the tree provided as of 2026-10-22:

- **Mesh shaders**, which AW2 requires: RADV exposes them on RDNA2, and the
  tree carried Mesa 26.2.5 with kernel 6.18.57.
- **`vm.max_map_count`** is 1048576, the nixpkgs default, so it is not set
  here.
- **`programs.gamescope.enable`** is already true, via steam's
  `gamescopeSession`.

There is no ProtonDB page, since the game is not on Steam. Community
reports install it through Heroic with GE-Proton. Reports from 2023–24
mention missing textures on Mesa
([GamingOnLinux](https://gamingonlinux.com/2023/10/ge-proton-8-22-released-with-fixes-for-alan-wake-2-metal-gear-solid-3)),
which predate the Mesa above by years. Not yet run on this host.

## Worth considering

Not done, each with what it would take:

- **Force GPU clocks during games.** Add a `[gpu]` section to
  `programs.gamemode.settings`: `apply_gpu_optimisations =
  "accept-responsibility"`, `gpu_device = 1` (durandal's `card1`),
  `amd_performance_level = "high"`. Small gain, more heat. `gpu_device`
  follows DRM card numbering, which changes if a second GPU is added.
- **LACT** (`services.lact.enable`) for fan curves, power limit, and
  undervolting on the 6700 XT. Undervolting also needs
  `hardware.amdgpu.overdrive.enable`, which changes the kernel command line.
- **A larger shader cache for AW2.** Set `MESA_SHADER_CACHE_MAX_SIZE` (for
  example `10G`) in Heroic's per-game environment rather than system-wide,
  if stutter returns after a cache fills.
- **GE-Proton for Steam from nixpkgs.** Add `proton-ge-bin` to
  `programs.steam.extraCompatPackages`, replacing protonup-qt's manual
  downloads. This does not help Heroic, which uses its own Wine Manager.
- **GameMode on tenacity.** Moving `programs.gamemode` into `gaming.nix`
  would reach tenacity too. Its governor switch competes with the power
  profile handling on a handheld, so check how it interacts with Jovian
  first.

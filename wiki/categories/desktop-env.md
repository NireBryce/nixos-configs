# `desktop-env` — `system/desktop-env/`

_Last modified: 2026-09-14_

## Contents

- [What's in it](#whats-in-it)
- [Why this category is never imported whole](#why-this-category-is-never-imported-whole)
- [Why the split happened](#why-the-split-happened)
- [Why `jovian-persist.nix` isn't filed under `impermanence`](#why-jovian-persistnix-isnt-filed-under-impermanence)
- [Imported by](#imported-by)
- [Known quirk: mouse/input lag for ~4.5s after resume on tenacity](#known-quirk-mouseinput-lag-for-45s-after-resume-on-tenacity)
- [See also](#see-also)

## What's in it

Two sub-areas, split along the same line as the hosts that use them:

- **`kde/`** — `kde-base.nix` (Plasma 6 and the bits every desktop host
  wants: `services.xserver.enable`, `services.desktopManager.plasma6.enable`,
  networking bits) and `kde-desktop.nix` (the workstation session on top of
  it: display manager, default session — everything specific to a machine
  that boots *to* a desktop rather than to a Steam session).
- **`jovian/`** — `jovian.nix` (the handheld half: Jovian, Steam, the TDP
  stack — generic to any machine with built-in controllers and an
  occasional SteamOS session, not specific to one host) and
  `jovian-persist.nix` (its persistence rule, split out 2026-08-14).

## Why this category is never imported whole

No host lists `desktop-env` in its imports — each names the one session
module it actually wants: `kde-desktop` (durandal, cube — pulls in
`kde-base` itself) or `jovian` (tenacity — also pulls in `kde-base`
itself, for the Plasma 6 desktop Jovian's SteamOS session drops back to).
That's why `kde-base.nix` is imported by *two different files*, not by the
category: `desktop-env` existing as a category still gives it a name and a
place to live, but nothing collects it as a bundle the way `system` or
`hardware` are collected.

`jovian-persist.nix` needing to be imported explicitly by `jovian.nix`
(rather than riding the category) is the sharpest illustration of this: it
was flagged as an *orphan* by `just modules` the moment it was created,
specifically because `desktop-env` is never imported whole.

## Why the split happened

Before the 2026-08-10 split, this was one `kde.nix` durandal imported whole
and tenacity didn't touch — tenacity got Plasma 6 from `jovian.nix` alone,
with no XWayland and none of the KDE applications, because `jovian.nix` set
`services.desktopManager.plasma6.enable = true` on its own without the rest
of what `kde-base.nix` now provides. `kde-base.nix`'s own header carries the
full history of what that cost.

## Why `jovian-persist.nix` isn't filed under `impermanence`

Deliberately kept as a sibling of `jovian.nix` rather than moved into
[impermanence](impermanence.md): moving it would hand `/etc/hhd`'s
persistence rule to every host that imports `impermanence`, including
durandal, which runs no handheld-daemon and has no reason to carry it. This
is the same "persistence lives beside what generates it, not centrally"
convention `libvirt-persist.nix`, `tailscale-persist.nix` and
`networkmanager-persist.nix` all follow too — see [system](system.md) and
[virtualization](virtualization.md).

## Imported by

Not imported as a category by anyone. `kde-base` reached transitively via
`kde-desktop` (durandal, cube) or `jovian` (tenacity).
`services.xserver`/Plasma 6 itself always arrives through one of those two,
never both.

## Known quirk: mouse/input lag for ~4.5s after resume on tenacity

Not a config bug, not USB/kernel-level — confirmed 2026-09-06 by reading the
installed package source. Kernel-side suspend/resume on tenacity (s2idle)
completes in well under 100ms, USB devices included. The lag comes from
`handheld-daemon`'s `adjustor` plugin: on a wake event it deliberately holds
off reapplying TDP/GPU/CPU-governor settings for a hardcoded delay —
`adjustor/drivers/smu/__init__.py`'s `SLEEP_DELAY = 4` and
`adjustor/drivers/gpu/__init__.py`'s `SLEEP_DELAY = 4.5` (package version
4.1.10; no comment in source explaining the number, but it reads as a
guard against writing to the SMU too soon after it resumes). Until that
delay elapses, whatever conservative clock state the firmware itself
resumed into is what the machine runs at — that's the felt "unresponsive
mouse" window, not a stuck input device.

Neither constant is exposed through `adjustor`'s `settings.yml` schemas or
any hhd TOML/UI config — grepped all of them, no sleep/wake knob exists.
The only ways to change it are patching the constant via a package
override (fragile across hhd updates, and may reintroduce whatever
instability the delay guards against) or an upstream ask to `hhd-dev`
(not filed — skill `propose-issue` only ever files in this repo, not
upstream). Decided not worth chasing; documented so a future session
doesn't re-diagnose it as a USB or kernel resume bug.

## See also

- [impermanence](impermanence.md) — `kde-sleepmode.nix` lives there, not
  here, even though it's KDE-specific — see that page for why.
- [../hosts.md](../hosts.md) — which host runs which session.
- `hosts/tenacity/configuration/plasma-tenacity.nix` — this host's own
  Plasma *preferences* (theme, kwin behavior, input devices, global
  shortcuts) via plasma-manager, captured from tenacity's live `~/.config`
  on 2026-09-01. A separate mechanism from everything above: home-manager
  class, wired in only through `tenacityConfiguration`'s own
  `home-manager.users.elly.imports`, not this category or `ellyHomeManager` —
  durandal, lysithea and cube never load plasma-manager's HM module.

  **It is a curated subset, not a 1:1 dump**, and what was left out was
  decided deliberately rather than missed. Excluded: the panel/widget layout
  (`plasma-org.kde.plasma.desktop-appletsrc`), because the live layout is two
  floating panels still rearranged by hand and pinning it would fight that;
  one `kwinrulesrc` window rule keyed by a per-install UUID that the live
  file's own `rules=` doesn't even reference; `kwinrc`'s `[Tiling]` and
  `[Desktops] Id_N` entries, which are generated identity rather than
  preference; the desktop wallpaper, which points at a file in `~/Downloads`
  that no Nix path can reference reproducibly; kickoff favourites ordering,
  same category as the panel layout; and `bluedevilglobalrc`'s per-adapter
  state, keyed to this machine's Bluetooth MACs. `kwalletrc` and plasma-nm's
  applet settings read as plausible Plasma 6 stock defaults, so they were
  left out rather than guessed at.

  **How the shortcuts were read**, which is the part worth not re-deriving:
  `kglobalshortcutsrc` runs ~350 lines because KDE dumps its entire default
  set to disk the first time anything touches it — not because 350 actions
  were rebound. Each line is `active,default,description`, so **diffing
  column 1 against column 2** recovers what actually changed, instead of
  guessing at stock KDE from memory. Doing that turned up the real story:
  nearly every default Meta-based kwin/plasmashell shortcut on tenacity has
  been deliberately *unbound*. Nothing in the repo records why (checked for a
  jovian/gamescope Meta-key claim; there isn't one), and an unbind is as much
  a customization as a rebind, so all of them are pinned.

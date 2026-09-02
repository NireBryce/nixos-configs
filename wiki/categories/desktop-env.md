# `desktop-env` — `nire/desktop-env/`

## Contents

- [What's in it](#whats-in-it)
- [Why this category is never imported whole](#why-this-category-is-never-imported-whole)
- [Why the split happened](#why-the-split-happened)
- [Why `jovian-persist.nix` isn't filed under `impermanence`](#why-jovian-persistnix-isnt-filed-under-impermanence)
- [Imported by](#imported-by)
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

## See also

- [impermanence](impermanence.md) — `kde-sleepmode.nix` lives there, not
  here, even though it's KDE-specific — see that page for why.
- [../hosts.md](../hosts.md) — which host runs which session.
- `nireHost/tenacity/configuration/plasma-tenacity.nix` — this host's own
  Plasma *preferences* (theme, kwin behavior, input devices, global
  shortcuts) via plasma-manager, captured from tenacity's live `~/.config`
  on 2026-09-01. A separate mechanism from everything above: home-manager
  class, wired in only through `tenacityConfiguration`'s own
  `home-manager.users.elly.imports`, not this category or `ellyHomeManager` —
  durandal, lysithea and cube never load plasma-manager's HM module.
- [../kde-to-wayland-migration.md](../kde-to-wayland-migration.md)
  — research-stage inventory of every explicit and implicit KDE dependency on
  durandal/tenacity (this page's `kde-base.nix`/`kde-desktop.nix`/`jovian.nix`
  *and* `plasma-tenacity.nix` above) and candidate Wayland-tiling-WM
  replacements for each, toward moving those two hosts off KDE. Nothing
  implemented yet, no WM chosen; `nire-cube` (also a `kde-desktop` importer)
  is explicitly out of scope for now.

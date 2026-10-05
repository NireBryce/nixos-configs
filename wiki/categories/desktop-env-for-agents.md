# `desktop-env`, for agents

_Last modified: 2026-10-05_

Condensed from [desktop-env.md](desktop-env.md). Facts only here.

## Category shape

- `general-config/desktop-env/`, two sub-areas split along the host
  line:
  - `kde/`: `kde-base.nix` (Plasma 6 + the bits every desktop host
    wants: `services.xserver.enable`, `services.desktopManager.plasma6.enable`,
    networking) and `kde-desktop.nix` (workstation session on top:
    display manager, default session).
  - `jovian/`: `jovian.nix` (handheld half: Jovian, Steam, the TDP
    stack) and `jovian-persist.nix` (its `/etc/hhd` persistence rule,
    split out 2026-08-14).
- **Never imported whole.** No host imports `desktop-env`; each names
  one session module: `kde-desktop` (durandal, cube — pulls in
  `kde-base` itself) or `jovian` (tenacity — also pulls in `kde-base`
  for the Plasma desktop SteamOS drops back to). Consequences:
  `kde-base` is imported by two different files, and
  `jovian-persist.nix` must be imported explicitly by `jovian.nix`
  (it was flagged as an orphan by `just modules` until it was).
- `jovian-persist.nix` lives here, not under
  [impermanence](impermanence.md): a move would hand `/etc/hhd`'s
  persistence rule to every impermanence host, including durandal,
  which runs no handheld-daemon. Same convention as `libvirt-persist.nix`,
  `tailscale-persist.nix`, `networkmanager-persist.nix`.
- History: one `kde.nix`, durandal-only, before the 2026-08-10 split;
  tenacity then got Plasma from `jovian.nix` alone (no XWayland, none
  of the KDE applications). Full account in `kde-base.nix`'s header.

## Imported by

durandal, cube via `kde-desktop`; tenacity via `jovian`. One session
per host, never both. Tenacity's Plasma *preferences* are a separate
mechanism: `host-config/tenacity/configuration/plasma-tenacity.nix`
(plasma-manager, wired only through `tenacityConfiguration`'s own
`home-manager.users.elly.imports`) — a curated subset, not a 1:1 dump;
the shortcut diff trick is column 1 vs column 2 of `kglobalshortcutsrc`
(`active,default,…` — KDE dumps all ~350 defaults to disk on first
touch; on tenacity nearly every default Meta shortcut is deliberately
unbound).

## Known: mouse/input lag ~4.5s after resume (tenacity)

Not USB/kernel — s2idle completes in under 100 ms including USB
(confirmed 2026-09-06 from installed package source). Cause:
`handheld-daemon`'s `adjustor` plugin deliberately delays reapplying
TDP/GPU/CPU-governor after wake — `SLEEP_DELAY = 4`
(`adjustor/drivers/smu/__init__.py`) and `4.5`
(`adjustor/drivers/gpu/__init__.py`), hhd 4.1.10. No knob in
`settings.yml` schemas or hhd TOML/UI (grepped). Options: package
override patching the constant (fragile, may reintroduce what the delay
guards against) or an upstream ask to hhd-dev (not filed). Left as is.

## Known: kwin threads on tenacity

- **Three-finger pinch zoom has no dedicated disable** (kwin upstream,
  [#228](https://github.com/NireBryce/nixos-configs/issues/228), decided
  leave-it 2026-09-09): the zoom effect registers it constructor-side
  with no config guard (kwin 6.7.4 `src/plugins/zoom/zoom.cpp:70,75`);
  the only lever kills the whole effect including the wanted
  Meta+Ctrl+scroll zoom (`zoom.cpp:167`). No per-device toggle in
  `kcminputrc`; plasma-manager exposes no gesture options. Escapes:
  nixpkgs overlay dropping the two registration calls (local kwin build
  per bump) or the magnifier effect swap (lens, no pinch). Not filed
  upstream.
- **Kickoff lags 1-3s+ to open; unresolved** ([#254](https://github.com/NireBryce/nixos-configs/issues/254),
  closed 2026-10-05, parked on the source page): Kickoff-specific
  (`vicinae` opens instantly, same kwin), mouse-opened, not ksycoca,
  GPU/CPU idle, a regression. EPP/frequency-ramp theory falsified (PR
  #257 closed unmerged). Next steps: `strace -p <plasmashell>` with
  `kernel.yama.ptrace_scope=0` temporarily, or `QT_LOGGING_RULES` debug
  categories + `journalctl --user -u plasma_plasmashell` around a repro.

## See also

[desktop-env.md](desktop-env.md) · [../hosts.md](../hosts.md) (which
host runs which session) · [impermanence.md](impermanence.md)
(`kde-sleepmode.nix` lives there, not here)

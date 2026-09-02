# Research: leaving KDE Plasma for a Wayland tiling WM

## Contents

- [What's actually in scope](#whats-actually-in-scope)
- [Full inventory](#full-inventory)
- [`plasma-manager` (tenacity) — landed after this doc's first draft](#plasma-manager-tenacity--landed-after-this-docs-first-draft)
- [Picking among Hyprland / niri / sway](#picking-among-hyprland--niri--sway)
- [Host-specific concerns](#host-specific-concerns)
- [Open questions](#open-questions)
- [Sources checked](#sources-checked)

**Written 2026-09-01 22:31 EDT, updated 2026-09-01 23:51 EDT after commit
`a0527f18`. Status: inventory + candidate replacements, nothing
implemented, no WM chosen yet.** Scope per Elly: `nire-durandal`
(workstation) and `nire-tenacity` (handheld, via Jovian's desktop-session
fallback). **`nire-cube` is explicitly out of scope** — it also imports
`kde-desktop` (`cube-configuration.nix:83`) and shares `kde-base.nix` with
the other two hosts; any refactor of `kde-base.nix` has to leave cube's
import working, or cube needs its own copy before `kde-base.nix` changes.

This is a research/planning doc, not a runbook — nothing here is "done means"
until a host actually boots into the replacement and someone checks off the
list below by hand, the way `wiki/homelab/backup-runbook.md` does for the
backup migration. Moved into `wiki/` verbatim from `claude cave/plans/` when
that directory was retired 2026-09-02 — see [history.md](history.md).

**Update, same day:** commit `a0527f18` ("feat: add tenacity-only
plasma-manager config from live KDE state") landed after this doc's first
draft and raises tenacity's migration cost — see
[plasma-manager (tenacity) — landed after this doc's first draft](#plasma-manager-tenacity--landed-after-this-docs-first-draft)
before treating tenacity as the smaller host to migrate.

## What's actually in scope

Everything KDE-shaped that durandal and/or tenacity currently get, in two
buckets:

1. **Explicit** — named directly in this repo's config (a `kdePackages.*`
   entry, a `programs.kdeconnect`/`kdeconnect`-adjacent option, a
   `kwriteconfig6` call, or — as of `a0527f18` — a `programs.plasma`
   declaration via plasma-manager).
2. **Implicit** — pulled in for free by
   `services.desktopManager.plasma6.enable = true`
   (`kde-desktop.nix:18`), which this repo's own comments have already found
   costly to get wrong once (see `kde-base.nix`'s history block: tenacity ran
   Plasma 6 without `services.xserver.enable` for a while, silently missing
   XWayland and the whole KDE app set). The same risk applies in reverse here
   — removing `plasma6.enable` removes things nothing in this repo's `.nix`
   files ever *named*, so this list has to be right or the replacement config
   will have silent gaps the way the original split did.

`kde-base.nix` (`services.xserver.enable`, `services.desktopManager.plasma6.enable`,
`networking.networkmanager.enable`, `programs.dconf.enable`, the package list,
`GTK_USE_PORTAL`) is the file both hosts actually get Plasma from — durandal
via `kde-desktop.nix` (which adds sddm + `defaultSession = "plasma"`),
tenacity via `jovian.nix` (which adds Jovian's own session handling instead).
Both would need a same-shaped replacement: a `<wm>-base.nix` with the shared
pieces, and each host keeping its own session-specific half.

## Full inventory

| What | Where today | Explicit/implicit | Candidate replacement | Notes |
|---|---|---|---|---|
| Plasma 6 session itself | `kde-desktop.nix:18` | explicit | Hyprland / niri / sway | see comparison below |
| `services.xserver.enable` | `kde-base.nix:15` | explicit | not needed — Wayland-native WMs don't want Xorg; XWayland is a separate, per-compositor option instead | this repo's own comment already flags this line as "still needed for xwayland" on X11-era assumptions; a tiling WM handles XWayland itself (`xwayland.enable` on Hyprland, built-in on sway/niri) |
| `sddm` + `defaultSession = "plasma"` | `kde-desktop.nix:25-31` | explicit | keep sddm (compositor-agnostic, widely used with Hyprland/niri/sway) or switch to `greetd` + `tuigreet`/`regreet` | sddm is not KDE-only; lowest-risk path is changing only `defaultSession`, not the display manager |
| `spectacle` (screenshots) | `kde-base.nix:30` | explicit | `grim` + `slurp` (region select), `swappy` (annotate) — `hyprshot`/`grimblast` if Hyprland | standard wlroots-ecosystem stack, no single drop-in GUI equivalent |
| `konqueror` (file manager / info pager) | `kde-base.nix:31` | explicit | depends what it's actually used for day to day — a GTK/Qt file manager (`pcmanfm-qt`, `nautilus`, `thunar`) if it's file browsing, `pinfo`/plain `info` in-terminal if it's really the GNU info pager use the comment claims | flagged as unclear usage — worth confirming with Elly before picking one |
| `qttools` | `kde-base.nix:32` | explicit | keep if any Qt app is still installed (partitionmanager, kwallet tooling); drop if not | Qt itself isn't KDE — only relevant if something Qt-based stays |
| `partitionmanager` | `kde-base.nix:33`, `elly-user.nix:25` | explicit | `gparted` (GTK), or keep `kdePackages.partitionmanager` — it's a standalone Qt app, runs fine outside Plasma | **needs a polkit agent** to keep working once Plasma's own is gone — see implicit row below |
| `kcharselect` (symbol picker) | `kde-base.nix:34` | explicit | GNOME Characters (`gnome-characters`), or `gucharmap` | low-stakes swap |
| `polonium`, `krohnkite` (KWin tiling scripts) | `kde-base.nix:35-36` | explicit | **nothing to replace** — the target WMs are tiling natively | these two exist only because KWin isn't a tiling WM by default; moving to Hyprland/niri/sway makes the whole category moot. `plasma-tenacity.nix` (below) explicitly sets `krohnkiteEnabled = false` — confirms it's installed but off, one less real preference to port |
| `libinput` ("kde middle mouse scroll fix") | `kde-base.nix:37` | explicit | check whether the fix is still needed outside KWin | KWin-specific workaround per its own comment; may be a no-op under a different compositor, may need a different fix — untested claim, don't assume either way |
| `GTK_USE_PORTAL=1` | `kde-base.nix:41` | explicit | keep | portal-based GTK file pickers are still correct outside KDE |
| `programs.dconf.enable` | `kde-base.nix:25` | explicit | keep | GTK apps still read dconf regardless of WM |
| `networking.networkmanager.enable` | `kde-base.nix:21` | explicit, `mkDefault` | keep NetworkManager; need a **systray applet or TUI** instead of Plasma's built-in one | `nm-applet` (GTK, works in any tray) or `nmtui`; already `mkDefault true` from `wifi.nix` independent of KDE (comment there: "Needs to be 'true' for KDE networking" is stale phrasing worth fixing once this lands either way, since NetworkManager is desktop-agnostic) |
| `programs.kdeconnect.enable` | `kde-connect.nix:7` | explicit | **may not need replacing at all** — the `kdeconnect` package/daemon runs standalone; it just needs a systray to live in and a GUI to configure devices (`kdeconnect-app`/`kdeconnectindicator`, or GSConnect if a GNOME box is ever in the mix) | check whether the current usage is just phone notifications/file transfer (works headless) vs. Plasma-integrated features (browser integration, KRunner search) |
| `kdePackages.xdg-desktop-portal-kde` | `xdg-portals.nix:26` | explicit | `xdg-desktop-portal-hyprland` (Hyprland — forked from wlr's, adds window-level screenshare) or `xdg-desktop-portal-wlr` (sway; more limited) or niri's current recommended portal (check niri's own docs at migration time, this moves) | `xdg-portals.nix:11-22` already has the wlr path scaffolded, commented out, from a 2026-08-21 attempt — half this work exists in the tree, needing uncommenting/updating rather than writing fresh |
| `kwriteconfig6` / PowerDevil sleep config | `kde-sleepmode.nix` (home-manager) | explicit | likely **deletable outright**, not replaceable | this file exists only because PowerDevil ignores logind's `AllowHibernation=no` and fails suspend outright instead of degrading (see file header, `lessons-learned.md` §30). `swayidle`/`hypridle` call `systemctl suspend` directly and should just respect what `WARN-impermanence.nix` already sets at the logind level — **needs verifying on the actual replacement**, not assumed, the same way the KDE bug itself was found by testing rather than guessed |
| `programs.plasma` via plasma-manager | `plasma-tenacity.nix` (tenacity only, landed `a0527f18`, 2026-09-01) | explicit | see dedicated section below — this is new and substantial, not covered by the rest of this table | tenacity-only; durandal/lysithea/cube never load plasma-manager's HM module |
| `ksshaskpass` (SSH_ASKPASS) | implicit — `programs.ssh` picks this based on `services.xserver.enable` | implicit | whatever the new WM's ecosystem uses (`ssh-askpass-fullscreen`, or drop askpass entirely and keep `bash.nix`/`zsh.nix`'s existing `unset SSH_ASKPASS` workaround, which already treats "no DISPLAY/WAYLAND_DISPLAY" as the safe case) | `bash.nix:79`, `zsh.nix:178` already carry the workaround for the ksshaskpass crash-over-plain-SSH bug; re-check whether it's still needed once the askpass binary changes |
| `kwalletd6` / KWallet | implicit (ships with plasma6) | implicit, used explicitly by `vscode.nix`'s `password-store: kwallet6` fix | `gnome-keyring` + libsecret (`services.gnome.gnome-keyring.enable` — doesn't require GNOME itself) and switch VS Code's `password-store` to `gnome-libsecret` | `vscode.nix:48` already names `gnome-libsecret` as "the other candidate" — this was scoped out once already, just needs doing. `plasma-tenacity.nix`'s own header notes kwalletrc's "never auto-lock" setting was found and deliberately left out as "plausible stock default" — one more thing to re-decide once KWallet itself is gone |
| polkit authentication agent | implicit (Plasma ships its own) | implicit, easy to miss | pick one explicitly: `polkit-kde-agent` (works standalone, doesn't need the rest of Plasma), `polkit-gnome`, `lxqt-policykit`, or `mate-polkit` | nothing in this repo currently names a polkit agent — it's riding on Plasma silently. **partitionmanager's privilege escalation depends on this existing**; losing it silently is the same class of bug `kde-base.nix`'s history block already warns about |
| Bluetooth GUI (bluedevil) | implicit | implicit | `blueman` (GTK, mature) or `overskride` (GTK4) | `plasma-tenacity.nix`'s header confirms bluedevilglobalrc *is* live state on tenacity (per-adapter `powered=`, left out of the capture as MAC-keyed and non-portable) — so bluetooth is confirmed in real use on tenacity, not hypothetical; budget for this one |
| Volume/audio mixer applet (plasma-pa) | implicit | implicit | `pavucontrol` (GUI) + a waybar/status-bar volume module, or `wireplumber`'s own CLI | pipewire itself isn't KDE-specific and doesn't need replacing |
| Display/output config (kscreen) | implicit | implicit | niri: its own config file (`outputs` section); Hyprland: `hyprctl`/`nwg-displays`; sway: `wlr-randr`/`nwg-displays`/`kanshi` for profile-switching | tenacity's `Xwayland.Scale = 1.25` (in `plasma-tenacity.nix`'s `configFile.kwinrc`) confirms HiDPI scaling is a real, deliberate setting on that host's small screen — the replacement WM's own output-scale config needs to carry this forward, not drop it |
| Terminal file manager / archive tool (Dolphin, Ark) | implicit | implicit | `pcmanfm-qt`/`nautilus`/`thunar`/`yazi` (TUI) for files; `xarchiver`/`file-roller`/CLI `zip`/`tar` for archives | not currently named anywhere in this repo's `.nix` — confirm whether Dolphin/Ark are actually used day to day, or whether the shell (`zsh.nix`/`bash.nix` already has a full CLI toolset) already covers it |
| PDF viewer (Okular) | implicit | implicit | `zathura` (keyboard-driven, fits a tiling-WM workflow) or `evince` | same caveat — not named anywhere explicit, confirm real usage first |
| Text editor (Kate/KWrite) | implicit | implicit | likely moot — `vscode.nix` exists and is the actual editor in use | low priority |
| Screen lock | implicit (KDE session lock) | implicit, explicit as of `plasma-tenacity.nix` | `swaylock` (sway), `hyprlock` (Hyprland), niri: any wlr-compatible locker (`swaylock` works) | `plasma-tenacity.nix`'s `shortcuts.ksmserver."Lock Session" = [ ]` **unbinds the default lock shortcut entirely** — a deliberate finding from diffing the live shortcut file, not an oversight. Whatever locker replaces this needs the *same* choice made again explicitly, or the handheld silently gets a lock shortcut back that was deliberately removed. Needed before this ships either way — a workstation and especially a *handheld that suspends* need a working lock screen from day one |
| Idle/suspend daemon | implicit (PowerDevil), now explicit in `plasma-tenacity.nix`'s `powerdevil` block | implicit/explicit | `swayidle` (sway/general wlroots), `hypridle` (Hyprland), niri: `swayidle` also works | `plasma-tenacity.nix` pins the *real*, verified behavior to port: power button and lid both trigger `sleep`/`turnOffScreen`, sleep mode is plain standby (never hibernate) on AC, battery, **and low battery** — this is now a concrete, non-guessable spec for whatever idle daemon replaces PowerDevil, not something to reconstruct from memory |
| Status bar / panel | implicit (Plasma panel: clock, tray, taskbar) | implicit | `waybar` (works with all three candidates) | none of the three target WMs ship one; this is mandatory infrastructure, not optional polish. `plasma-tenacity.nix`'s header notes the *live* panel/widget layout on tenacity was deliberately left out of the capture (still hand-rearranged) — so there's no declarative spec to port here, just a live layout to look at before building the waybar equivalent |
| App launcher | implicit (KRunner) | implicit | **already solved** — `vicinae.nix` (a Raycast-for-Linux launcher) already exists and carries a `plasma-workspace.target` dependency that needs retargeting (`vicinae.nix:48`) to the new WM's equivalent "session is up" target | a unit-ordering fix, not a new tool to pick; `plasma-tenacity.nix`'s `shortcuts` block also binds vicinae's launch keys (`Menu`, `Meta+Backspace` — reusing the key KWin's own "Window Restore" gave up), which belong in the new WM's keybind config too |
| Notification daemon | implicit (Plasma's own) | implicit | `mako` (sway/wlroots-general), `dunst` (WM-agnostic), Hyprland: `hyprland-plugins` notification or `mako`/`dunst` also work | needed day one, same as screen lock |
| Keyboard layout/model + xkb options | implicit (kxkbrc) | now explicit via `plasma-tenacity.nix` | any compositor's own `input` config (Hyprland `input {}`, niri `input {}`, sway `input *`) | concrete values to carry over: keyboard model `microsoftinet`, xkb options `terminate:ctrl_alt_bksp` and `altwin:menu` — both hand-set, not defaults |
| Per-device mouse/touchpad tuning | implicit (kcminputrc) | now explicit via `plasma-tenacity.nix` | same compositors' per-device `input` matching (Hyprland `device {}` blocks by name, sway `input <identifier>`, niri per-device sections) | concrete values: Logitech G600 at raw/no-accel, a second mouse forced left-handed, the built-in touchpad's `pointerSpeed = 0.200` — all keyed by vendor/product IDs in the KDE version, will need re-matching by whatever identifier scheme the new compositor uses (often the evdev device name string, not vendor/product hex) |
| Virtual desktop grid shape | implicit (kwinrc `[Desktops]`) | now explicit via `plasma-tenacity.nix` | Hyprland/sway: named workspaces, no native "grid" concept — would need a wrapper (e.g. a rows×cols convention in keybinds) or dropping the 2×2 framing; niri: scrollable-tiling has no grid concept at all, this preference may not port cleanly | 4 desktops in a 2×2 layout is a Plasma-specific framing; **niri in particular may not have an equivalent concept**, which is a real workflow-shape question, not just a config translation — worth weighing when picking a WM (see comparison below) |
| Accessibility: sticky keys | implicit (kaccessrc) | now explicit via `plasma-tenacity.nix` | `xkb` sticky-keys option (works compositor-agnostically, it's an XKB feature not a KDE one) or the compositor's own accessibility settings if any | `StickyKeys = true` plus `AccessXBeep`/`GestureConfirmation` — real, deliberate handheld-specific accessibility config (cramped keyboard chording), not a default; must not get silently dropped |
| Compositor visual behavior (alt-tab style, border size, desktop-switch OSD, touch-point visualization) | implicit (kwinrc) | now explicit via `plasma-tenacity.nix` | Hyprland/sway/niri all have their own equivalents for some of these (Hyprland has switcher plugins, border config is universal) but **touch-point visualization and a desktop-switch OSD are Plasma-specific conveniences** with no guaranteed equivalent | `TabBoxAlternative.LayoutName = "coverswitch"`, `BorderSizeAuto = false`, `desktopchangeosdEnabled`, `touchpointsEnabled` — the last one matters specifically because tenacity is a touchscreen handheld; losing it is a real regression to weigh, not cosmetic |

## `plasma-manager` (tenacity) — landed after this doc's first draft

Commit `a0527f18` (2026-09-01, same day as this doc) added
`flake/modules/nireHost/tenacity/configuration/plasma-tenacity.nix`: a
curated, deliberately-not-exhaustive capture of tenacity's *live* KDE
preferences via plasma-manager, wired only through
`tenacityConfiguration`'s own `home-manager.users.elly.imports` (not
`ellyHomeManager`, so the other three hosts never load it).

**Net effect: tenacity did not get closer to WM-agnostic — it got a
larger, precisely-specified KDE footprint to translate.** Before this
commit its undeclared `~/.config` state was a black box; now the values
above (device tuning, shortcuts, power behavior, accessibility, visual
behavior) are committed and reviewable. Two framings both true:

- It **raises** the tenacity-specific work the migration has to redo.
- It **removes** the "reconstruct from live state" risk — the values
  survive a `/root` wipe or reinstall. Durandal has no equivalent capture;
  its undeclared `~/.config` is still a black box.

One workflow-shape question this surfaces: the 2×2 virtual-desktop grid and
KWin's alt-tab/window functions don't map onto niri's scrollable-tiling
model at all, and only partially onto Hyprland/sway's — see the
[WM comparison](#picking-among-hyprland--niri--sway).

## Picking among Hyprland / niri / sway

Not decided — Elly asked for the category, not a specific pick. Rough
tradeoffs found while researching the table above, for whoever decides:

- **Hyprland** has the most mature portal (`xdg-desktop-portal-hyprland`,
  window-level screenshare, not just per-output) and the largest ecosystem
  of prebuilt bar/lock/idle tooling (`hyprlock`, `hypridle`). It also has
  **a working precedent with Jovian** — the blog post `jovian.nix`'s own
  footer links (ciarandegroot.com's NixOS Steam Box writeup, in Sources
  below) is about exactly this combination; read it in full before starting
  tenacity's side. Its workspace model (numbered, not a fixed grid) is the
  closest fit for porting tenacity's 2×2 virtual-desktop preference, though
  not identical.
- **niri** is scrollable-tiling rather than grid-tiling — a different
  workflow, not just a different implementation of the same one. Its portal
  story is the least settled of the three as of this research; check niri's
  own docs at implementation time rather than trusting this doc's snapshot.
  **Now a harder sell specifically for tenacity** given the plasma-manager
  capture above: niri has no real equivalent to a 2×2 virtual-desktop grid,
  so that preference wouldn't just need translating, it would need dropping
  or reframed.
- **sway** is the most conservative choice (i3-compatible config, oldest and
  most-documented of the three), but `xdg-desktop-portal-wlr` is the
  weakest portal of the three for screen sharing — this repo's own
  commented-out scaffold in `xdg-portals.nix:11-22` was written against sway
  in mind and never finished.

No recommendation is being made here beyond: **Hyprland has the least open
risk** (portal maturity + an existing Jovian precedent + the closest
workspace-model fit for tenacity's captured preferences), the other two are
real options if their tradeoffs matter more than that.

## Host-specific concerns

- **durandal**: the more contained change — `kde-desktop.nix` becomes
  `<wm>-desktop.nix` or similar, session module swaps, done. No Jovian
  interaction, and **no plasma-manager capture exists for it** — unlike
  tenacity, whatever's undeclared in durandal's `~/.config` is still an
  unknown quantity. A similar live-state capture pass on durandal, before
  migrating it, would close the same gap `a0527f18` closed for tenacity —
  worth doing first rather than discovering the gaps mid-migration.
- **tenacity**: `jovian.steam.desktopSession = "plasma"`
  (`jovian.nix:54`) is **confirmed to accept any registered session name**,
  not just KDE/GNOME — Jovian's own docs describe it as "the name of an X11
  or Wayland session of your choosing," same semantics as
  `services.displayManager.defaultSession`, and setting an invalid string
  gets you a listing of valid options for the system (see Sources below).
  So this is a config-value change, not a Jovian-compatibility question.
  Now also carries the whole `plasma-manager` translation cost described
  above. Two more things specific to tenacity that need re-verifying once
  the session changes:
  - `handheld-daemon`'s `ui.enable` overlay renders through gamescope, not
    the desktop session, so should be unaffected — but confirm, don't
    assume, the same way `jovian.nix`'s own comments insist on for
    everything else in that file.
  - The hhd-ui "benign crashes in a Plasma session" comment
    (`jovian.nix:151-172`) is Plasma-specific behavior Jovian's overlay
    thread has; re-check whether the same crash-and-recover pattern happens
    under the new WM or whether it changes shape.

## Open questions

- Which of Hyprland/niri/sway, and who decides — not resolved here.
- Real usage check needed before picking replacements for the "implicit,
  not currently named anywhere" rows (Dolphin, Ark, Okular, Kate):
  confirm what's actually used day to day on durandal/tenacity before
  spending effort on a replacement nothing needs. (Bluetooth is now
  confirmed in real use on tenacity via `plasma-tenacity.nix`'s header, so
  drop that one from this list.)
- `konqueror`'s actual use case — file manager vs. info pager — needs
  confirming with Elly; the two have different replacements.
- Whether `kde-sleepmode.nix` can simply be deleted once PowerDevil is gone,
  or whether the new idle daemon needs its own equivalent fix — flagged
  above as "needs verifying on the actual replacement," not assumed. Note
  `plasma-tenacity.nix`'s `powerdevil` block now gives the *exact* behavior
  to reproduce (standby-only, never hibernate, at every battery level), so
  this is now a testable spec rather than a vague requirement.
- `libinput`'s "kde middle mouse scroll fix" (`kde-base.nix:37`) — untested
  whether this is KWin-specific or general.
- Whether the 2×2 virtual-desktop grid preference should be preserved
  verbatim, reframed, or dropped, given niri (and to a lesser extent
  Hyprland/sway) don't have a native grid concept — a real decision, not a
  config-translation detail.
- Should durandal get its own live-state capture (plasma-manager or
  otherwise) before its migration, the way tenacity just did? No such
  capture exists for durandal today.
- Whether cube ever gets pulled into this later, and if so whether
  `kde-base.nix` gets forked or cube gets migrated too — explicitly not
  this round.

## Sources checked

- [Jovian-NixOS Configuration docs](https://jovian-experiments.github.io/Jovian-NixOS/configuration.html) — `desktopSession` semantics.
- [ciarandegroot.com — Turn Your PC Into a Steam Box with Jovian-NixOS](https://ciarandegroot.com/posts/nixos-steam-box/) — already linked from `jovian.nix`'s own footer; worth a full read for the Hyprland-specific parts before implementing tenacity's side.
- [Hyprland wiki — Hyprland Desktop Portal](https://wiki.hypr.land/0.41.2/Useful-Utilities/xdg-desktop-portal-hyprland/) — xdph is a fork of xdg-desktop-portal-wlr with added window-level screenshare.
- Everything else in this doc is from reading this repo's own tree (`kde-base.nix`, `kde-desktop.nix`, `jovian.nix`, `kde-connect.nix`, `kde-sleepmode.nix`, `xdg-portals.nix`, `vicinae.nix`, `vscode.nix`, `obsidian.nix`, `espanso.nix`, `bash.nix`, `zsh.nix`, `elly-user.nix`, `wifi.nix`, `plasma-tenacity.nix`, host configs) as of 2026-09-01, not from memory.

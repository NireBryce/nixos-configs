# Temporary patches and hacks

_Last modified: 2026-10-22_

This page lists every workaround in this config that exists only because a
third-party project has a bug, with what each one works around and when it
can be undone. Each one stays until the bug is fixed upstream, and nothing
removes it for you: an input bump that fixes the bug leaves the workaround
in place. Check this list when a lock bump lands and whenever a host build
breaks inside something listed here.

The bugs themselves are tracked as GitHub issues labelled `upstream`, with
paste-ready write-ups in `_loose-ends/bugs-pending-submission/`
([open-threads.md](open-threads.md)). None of them has been filed upstream;
that still needs the user to ask, report by report.

## Contents

- [Quick facts](#quick-facts)
- [Live workarounds](#live-workarounds)
- [Threads with no workaround in the config](#threads-with-no-workaround-in-the-config)
- [Not on this page, on purpose](#not-on-this-page-on-purpose)
- [Adding one](#adding-one)

## Quick facts

| workaround | file | host | upstream bug | undo when |
|---|---|---|---|---|
| sign `acpi_call` with kmodigest | `flake/modules/general-config/desktop-env/jovian/jovian.nix` (`boot.kernelPackages` override) | nire-tenacity | nixpkgs `acpi_call` installs no `.ko.cer`; no issue yet | nixpkgs' package ships the `.cer` itself (the build fails on purpose when it does) |
| re-declare Valve's cmdline minus `amd_iommu=off` | `flake/modules/host-config/tenacity/fixes/iommu-tenacity.nix` | nire-tenacity | [#443](https://github.com/NireBryce/nixos-configs/issues/443) (Jovian) | Jovian stops setting `amd_iommu=off` for non-Deck hardware, or its param list changes (re-diff) |
| blacklist `tiny_power_button` | `flake/modules/general-config/boot/power-button/no-tiny-power-button.nix` | every host in the `boot` category (durandal, tenacity, cube) | Linux 6.18.57's partial backport of 6.19's ACPI button rework; no issue yet | any kernel bump: eval warns when the kernel is no longer 6.18.57; re-check, then drop |
| null out avahi's deprecated `publish.{enable,userServices}` | `flake/modules/general-config/system/gaming/sunshine.nix` | every NixOS host | nixpkgs `sunshine.nix` still sets them; no issue yet | nixpkgs' `sunshine.nix` sets `services.avahi.settings.publish` itself |
| replace a `read` in `_carapace_completer` | `flake/modules/general-config/shell-config/bash/carapace-completer-read-fix.bash`, sourced from `bash.nix` | all with bash + ble.sh | [#75](https://github.com/NireBryce/nixos-configs/issues/75) (ble.sh/carapace) | the repro no longer reproduces with the fix removed |

None of these is removed on the strength of a version bump alone: each
section below says what to run first.

## Live workarounds

### acpi\_call has no module certificate

Added 2026-10-20, the day the lock bump broke tenacity's build.

**What breaks without it.** nixpkgs now signs kernel modules with
`kmodigest` during Kbuild's `modules_install`, which leaves a
`<module>.ko.cer` next to every module. The aggregator that builds
`linux-<version>-modules` (`pkgs/os-specific/linux/kmod/aggregator.nix`)
concatenates the `.cer` of every external module. nixpkgs' `acpi_call`
package copies its `.ko` into place by hand instead of running
`modules_install`, so it has no `.cer`, and the toplevel build fails:

```
cat: misc/acpi_call.ko.cer: No such file or directory
```

**What it does.** `jovian.nix` replaces `acpi_call` inside
`boot.kernelPackages` (`pkgs.linuxPackages.extend`) with a copy whose
`installPhase` runs `kmodigest` on the installed module, which is what
`modules_install` would have done. The replacement is in `kernelPackages`,
not in the `boot.extraModulePackages` line, because nixpkgs' own
`handheld-daemon` module adds a second `acpi_call` through
`adjustor.loadAcpiCallModule`.

**Undo when** all of these hold (the code comment carries the same list):

1. nixpkgs' `acpi_call` installs `acpi_call.ko.cer` itself. The override
   checks for this and fails the build with a pointer to `jovian.nix`, so
   a lock bump will announce it.
2. With the override deleted, `just host=nire-tenacity build` succeeds.
   `just check` alone does not reach the aggregator.
3. After switching, `modinfo acpi_call` resolves and hhd's TDP control
   still works.

It also goes if tenacity stops loading `acpi_call` at all.

### Jovian turns the IOMMU off on tenacity

Added 2026-08-12; tracked as
[#443](https://github.com/NireBryce/nixos-configs/issues/443), write-up
`_loose-ends/bugs-pending-submission/2026-08-12-bugreport-jovian-amd-iommu-s0i3.md`.

**What breaks without it.** Jovian's
`jovian.steamos.enableDefaultCmdlineConfig` adds Valve's Steam Deck kernel
parameters, including `amd_iommu=off`. tenacity's Phoenix APU has an NPU
that the IOMMU must be on for, and with it off the machine reaches 0%
hardware sleep while suspended (23.65 W, fan running).

**What it does.** `iommu-tenacity.nix` turns that option off and
re-declares Valve's parameter list without `amd_iommu=off`. Suspend went
to 92.5% hardware-sleep residency on the first boot with it applied.

**Undo when** Jovian stops applying `amd_iommu=off` on non-Deck hardware
(gating on Deck, or on NPU presence). Until then, also re-diff the module's
copied list against Jovian's `modules/steamos/boot.nix` after a Jovian
bump: a parameter Valve adds upstream does not reach tenacity while this
override exists. To confirm after removal, suspend and read
`/sys/power/suspend_stats/last_hw_sleep` (not `amd-s2idle`'s percentage;
see [#442](https://github.com/NireBryce/nixos-configs/issues/442)).

### tiny\_power\_button powers off on a power-button press

Added 2026-10-20, after the kernel bump to 6.18.57.

**What breaks without it.** `tiny_power_button` is the kernel's power
button driver for VMs: a press makes the kernel send `SIGRTMIN+4` to init
(`kill_cad_pid`), and systemd powers off immediately, before logind or the
desktop sees the key. It is meant to replace the normal `button` driver
(Kconfig `depends on !ACPI_BUTTON`), but nixpkgs builds both as modules with
the same ACPI aliases, so udev loads both. On 6.18.57, which carries part of
6.19's conversion of `button` to a platform driver, tiny binds the ACPI
power-button device (`PNP0C0C:00`) and the button powers the machine off
whatever `HandlePowerKey` and PowerDevil say. Seen on tenacity: a
`signal_generate` trace showed `acpi_ev_notify_dispatch → kill_cad_pid`. The
same partial backport left the button dead on another machine:
<https://bbs.archlinux.org/viewtopic.php?pid=2312287>.

**What it does.** `no-tiny-power-button.nix` adds `tiny_power_button` to
`boot.blacklistedKernelModules`, which stops the alias autoload. It also
records the kernel it was confirmed on (6.18.57) and adds an eval warning
when the host's kernel is any other version.

**Undo when** the kernel changes at all: any kernel bump, point release
included, is the cue (the eval warning says so). On the new kernel, remove
the blacklist, boot, and check that `/sys/bus/acpi/drivers/tiny-power-button/`
binds nothing and a power-button press suspends. If it still binds
`PNP0C0C:00`, keep the blacklist and move `confirmedOn` to the new version.

### sunshine sets avahi options nixpkgs deprecated

Added 2026-10-21.

**What breaks without it.** nixpkgs' `sunshine` module turns avahi on with
`services.avahi.publish.enable` and `publish.userServices` (both
`mkDefault`). The avahi module deprecated both in favour of
`services.avahi.settings.publish`, so every evaluation of every NixOS host
prints two "option is obsolete" warnings. Nothing misbehaves.

**What it does.** `sunshine.nix` sets both options to `null` at normal
priority, which drops the module's values and the warnings, and sets
`settings.publish.disable-user-service-publishing = false` (what
`userServices = true` used to derive). `avahi.nix` sets the other two keys.
The rendered `services.avahi.settings.publish` is unchanged on every host.

**Undo when** nixpkgs' `sunshine.nix` sets `services.avahi.settings.publish`
itself. Delete the block, evaluate, and check the warnings stay gone and
`services.avahi.settings.publish` is the same as before.

### carapace's completer loses a race with ble.sh

Added 2026-08-24; tracked as
[#75](https://github.com/NireBryce/nixos-configs/issues/75). Full
mechanism and undo procedure:
`flake/modules/general-config/shell-config/bash/carapace-read-fix.md`.

**What breaks without it.** While typing quickly in a carapace-completed
command, bash prints ``read: `': not a valid identifier`` repeatedly.
ble.sh's cancellation hook catches the `read` at the end of carapace's
generated `_carapace_completer` mid-call and splits its arguments wrongly.

**What it does.** `carapace-completer-read-fix.bash` redefines
`_carapace_completer` with that `read` replaced by a parameter-expansion
split, so there is no `read` for ble.sh to catch. If carapace's template
changes so the expected line is gone, the file prints a warning instead of
patching.

**Undo when** either ble.sh's cancellation path stops corrupting an
in-flight `read`, or carapace's completer stops using `read` there. Check
by removing the fix and re-running the repro from `carapace-read-fix.md`
(`terminal-puppeteer`, `git co` TAB CTRL-C a few times). Silence after a
carapace bump is not evidence; the tripwire warning is the signal to look.

## Threads with no workaround in the config

These are in the same loose-ends set but nothing in the config works
around them, so there is nothing to undo:

- [#444](https://github.com/NireBryce/nixos-configs/issues/444), nixpkgs
  vscode patching the wrong ripgrep on Linux. The fleet is not affected at
  vscode 1.136.1 (re-checked 2026-09-16); upstream's code still has the
  asymmetry, so a later vscode layout could expose it again.
- [#442](https://github.com/NireBryce/nixos-configs/issues/442),
  `amd-s2idle` reports hardware-sleep residency 100× too high. Avoided by
  reading the kernel counter instead of the tool's percentage.
- ZCode 3.15.3 not persisting hook-trust approval
  (`_loose-ends/bugs-pending-submission/2026-10-19-bugreport-zcode-hook-trust-approval-not-persisted.md`).
  The workaround, a direct `hooks trust grant`, was run once by hand and
  left state on disk under `~/.zcode`, not in this config. Nothing to undo
  here; the write-up says what to keep.
- KDE bug 513595: every KDE login logs "Could not register app ID" from the
  portal clients, which can leave the portal daemon's KIO connection
  uninitialised for the session. No fix in the config; the manual workaround
  is `systemctl --user restart xdg-desktop-portal.service
  plasma-xdg-desktop-portal-kde.service` after login
  (`flake/modules/general-config/system/xdg/xdg-portals.nix` history block).
- Tenacity's internal SD card reader intermittently failing to enumerate
  since 6.18.57, which also delays the lock screen's YubiKey prompt
  ([experiments/tenacity-sd-reader-enumeration.md](experiments/tenacity-sd-reader-enumeration.md)).
  Suspected cause is a 6.18.56 USB hub change; tabled until a kernel bump.
  Recheck on the same bump that retires the `tiny_power_button` blacklist.

## Not on this page, on purpose

Fixes for hardware behaviour are permanent, not temporary:
`durandal/fixes/b550-suspend-fix.nix` (kept local on purpose although
nixos-hardware now ships the same rule; its comment says why) and
`tenacity/fixes/touchscreen-wakeup-tenacity.nix`. Workarounds that have
already been removed are recorded in their module's history block; for
example `jovian.nix` once carried an hhd `pkg_resources` overlay
(2026-08-10 to 2026-09-13).

## Adding one

A new workaround for a third-party bug gets, in the same change:

1. A code comment that says why, starts with `TEMPORARY`, and lists the
   conditions for removal.
2. Where it can, a check that fails the build once upstream fixes the bug
   (the `acpi_call` override's `.cer` test, the old hhd overlay's
   `--replace-fail`), so the fix announces itself instead of the
   workaround outliving it.
3. A row in Quick facts and a section here.
4. A tracking issue (skill `propose-issue`). Filing upstream still needs
   the user to ask.

Removing one: delete its row and section in the same change, and leave a
dated line in the module's history block.

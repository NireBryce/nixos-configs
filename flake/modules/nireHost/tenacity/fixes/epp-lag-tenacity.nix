# kwin menu popups lag on opening (issue #254). Same shape as
# touchscreen-wakeup-tenacity.nix -- an ATTR write on a udev add event --
# but for a CPU frequency-scaling knob rather than a wakeup source.
#
# Diagnosed 2026-09-09 from real journal evidence, not source-reading:
# `journalctl --user -b 0 -u plasma-kwin_wayland.service` showed libinput's
# own "your system is too slow" warnings recurring during ordinary
# interactive use on this boot (event processing lagging behind, key
# repeat discarded because "Wayland compositor doesn't seem to be
# processing events fast enough"). That's a real compositor stall, not a
# guess.
#
# This host's amd_pstate is active (`cat
# /sys/devices/system/cpu/amd_pstate/status`) with every core parked at
# `energy_performance_preference=power` -- amd-pstate's most conservative
# setting, and the one most likely to visibly under-ramp when a sudden UI
# burst (a new compositor surface, e.g. a popup menu) needs a frequency
# jump the core wasn't sitting at. `power-profiles-daemon.service` is
# masked on this host -- handheld-daemon/hhd owns TDP instead -- so nothing
# already steers EPP away from the driver default; this had never been set
# by anything in this repo.
#
# `balance_performance` is the one-step-less-conservative neighbor, not
# `performance` -- a deliberate hedge on a battery-powered handheld rather
# than trading all the way to max power draw for a menu-open fix.
#
# NOT independently confirmed against the menu itself: verifying this needs
# writing the sysfs node as root, which the diagnosing session had no way
# to do (no sudo, no GUI input simulation available to it), only reading
# the existing value. Confirmed here: the mechanism, and that this repo had
# nothing setting EPP before now. Unconfirmed: that this specific value
# change is what removes the felt lag -- check on hardware after a real
# `just switch` (`cat
# .../cpufreq/energy_performance_preference` should read
# `balance_performance` post-boot, and the felt menu lag should be gone;
# if it persists, re-open issue #254 rather than assuming this fixed it).
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            services.udev.extraRules = ''
            SUBSYSTEM=="cpu", ACTION=="add", ATTR{cpufreq/energy_performance_preference}="balance_performance"
            '';
        };
}

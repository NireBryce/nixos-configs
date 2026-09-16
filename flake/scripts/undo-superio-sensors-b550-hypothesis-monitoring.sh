#! /usr/bin/env bash
# Unload the hand-loaded superio sensor driver (out-of-tree it87 plus its
# hwmon-vid dependency), from the durandal suspend investigation
# (wiki/experiments/durandal-auto-suspend-hang.md).
#
#   undo-superio-sensors-b550-hypothesis-monitoring.sh
#
# Confirmed 2026-09-16: `Found IT8688E chip at 0xa40, revision 1`. The
# in-tree it87 stops at it8795 and does NOT know that chip;
# `linuxPackages.it87` (frankcrawford/it87) does -- hence loading by explicit
# store path with `insmod`, because `modprobe it87` resolves the name against
# /lib/modules and loads the WRONG, in-tree module. It also needs its
# hwmon-vid dependency loaded first, which insmod will not do for you:
#
#   sudo modprobe hwmon-vid
#   sudo insmod <store-path>/it87.ko ignore_resource_conflict=1 update_vbat=1
#
# Both parameters are required here, not optional. Without the first, load
# fails on an ACPI resource conflict; without the second, Vbat reports the
# stale power-up value rather than a live one.
#
# What it was loaded to answer: this chip exposes VBAT and the 3VSB standby
# rail -- the rail that holds DRAM alive through S3, and so through the PSU
# power-cut that recovers a hang. Both read healthy on 2026-09-16, 3VSB at
# 3.26V (nominal 3.3) and Vbat at 3.19V (fresh CR2032 is ~3.0-3.3), which
# rules out a dying CMOS battery and gross standby-rail failure. Only those
# two are trustworthy without a board-specific sensors.conf: they are
# internal to the superio, whereas in0-in6 sit behind board dividers and are
# unscaled nonsense as absolute values. And all of it is sampled while the
# machine is AWAKE -- it cannot observe the rail during the S3 failure,
# because nothing is executing then.
#
# That load is a hand test, not config: it touches nothing on disk and is
# gone on reboot. This script is the tidy-up for when the answer is in,
# rather than leaving a superio driver bound on a machine whose firmware is
# already under suspicion.
#
# Order matters: it87 depends on hwmon-vid, so it87 comes off first.
# hwmon-vid is left alone if anything else is still using it -- it is a
# shared in-tree module and may not have been loaded for this.
set -euo pipefail

if (($# != 0)); then
    echo "usage: undo-superio-sensors-b550-hypothesis-monitoring.sh" >&2
    exit 2
fi

# refcount from /proc/modules; empty if the module isn't loaded at all
refcount() {
    awk -v m="$1" '$1 == m { print $3 }' /proc/modules
}

loaded() {
    [[ -n "$(refcount "$1")" ]]
}

# Hand-applied PM debug toggles. Set by hand during the investigation, NOT
# by config -- pm_print_times is set from the probe module via tmpfiles, so
# this only reverts a manual override back to that module's value on the
# next boot, it does not fight it.
pm_toggles=(/sys/power/pm_print_times /sys/power/pm_debug_messages)

stray_conf=/etc/sensors.d/b550m-ds3h.conf

work=0
loaded it87 && work=1
loaded hwmon_vid && work=1
[[ -e $stray_conf ]] && work=1
for f in "${pm_toggles[@]}"; do
    [[ -e $f && $(cat "$f" 2>/dev/null) != 0 ]] && work=1
done

if ((work == 0)); then
    echo "nothing hand-applied is still in place -- nothing to do."
    exit 0
fi

if ((EUID != 0)); then
    echo "needs root to rmmod; re-run with sudo." >&2
    exit 1
fi

if loaded it87; then
    users=$(refcount it87)
    if ((users > 0)); then
        echo "it87 still has $users user(s); refusing to force it off." >&2
        exit 1
    fi
    rmmod it87
    echo "unloaded it87"
else
    echo "it87 was not loaded"
fi

# Only ours to remove if nothing else took a reference. lm_sensors and other
# hwmon drivers legitimately pull this in.
if loaded hwmon_vid; then
    users=$(refcount hwmon_vid)
    if ((users > 0)); then
        echo "hwmon_vid left loaded -- $users other user(s) still hold it"
    else
        rmmod hwmon_vid
        echo "unloaded hwmon_vid"
    fi
else
    echo "hwmon_vid was not loaded"
fi

# A hand-dropped sensors.d file is NOT config -- the repo installs nothing
# there. Anything present was put there by hand and outlives a reboot,
# unlike the module, so it is the piece most likely to be forgotten.
if [[ -e $stray_conf ]]; then
    rm -f "$stray_conf"
    echo "removed hand-placed $stray_conf"
fi

for f in "${pm_toggles[@]}"; do
    [[ -e $f ]] || continue
    v=$(cat "$f" 2>/dev/null)
    if [[ $v != 0 ]]; then
        echo 0 > "$f" && echo "reset $(basename "$f") ($v -> 0)"
    fi
done

echo
echo "hwmon devices now:"
for h in /sys/class/hwmon/hwmon*; do
    [[ -e "$h/name" ]] && echo "  $(basename "$h"): $(cat "$h/name")"
done

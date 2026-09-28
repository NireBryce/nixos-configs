# Stop the built-in touchscreen from waking the handheld.
#
# Same shape and reason as durandal/fixes/b550-suspend-fix.nix -- a device
# armed for wakeup that should not be -- but this one was picked out of the
# journal rather than inherited from nixos-hardware.
#
# Measured on 2026-08-12, ~9.5h uptime, from /sys/class/wakeup:
#
#     i2c-HTIX5288:00   298,387 events     <- this
#     serio0             11,846
#     ACAD                    9
#     PNP0C0C:00              5
#
# 25x the next source, and `power/wakeup` was `enabled`. HTIX5288 is the Himax
# I2C touch controller at /sys/devices/platform/AMDI0010:00/i2c-0/.
#
# Wanted for its own sake -- a handheld that wakes because something brushed
# the screen in a bag is the failure this prevents. Whether it ALSO fixes the
# deeper problem is unproven: every suspend this boot logged
#
#     amd_pmc AMDI0009:00: Last suspend didn't reach deepest state
#
# with /sys/power/suspend_stats/last_hw_sleep at 0 -- the machine holds sleep
# fine (one cycle ran 1h36m) but never enters hardware sleep, so it drains
# roughly like an idle awake machine. An active I2C HID device is the usual
# suspect for blocking s0i3 on AMD, which is why this is a reasonable first
# move, but the blocker is named by
#
#     sudo cat /sys/kernel/debug/amd_pmc/s0ix_stats
#
# and that had not been read when this was written. There is no S3 to fall
# back to either: /sys/power/mem_sleep offers only [s2idle]. If deep sleep is
# still not reached after this, the answer is in that debugfs file, not here.
#
# The match is the exact enumerated name. If the instance suffix ever changes,
# this rule silently stops applying rather than erroring -- check
# `cat /sys/class/wakeup/*/name` before assuming it is still in effect.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            services.udev.extraRules = ''
            ACTION=="add|change", SUBSYSTEM=="i2c", KERNEL=="i2c-HTIX5288:00", ATTR{power/wakeup}="disabled"
            '';
        };
}

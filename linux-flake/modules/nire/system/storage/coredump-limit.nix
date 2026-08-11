# A size backstop for the coredump store. NOT a fix for it never being cleaned
# -- it is cleaned, correctly, and an earlier version of this comment said
# otherwise.
#
# What is already true without this file: systemd ships
# `d /var/lib/systemd/coredump 0755 root root 2w` in tmpfiles, and
# systemd-tmpfiles-clean.timer runs it daily. Checked on tenacity 2026-08-11 --
# the timer had run ten minutes earlier and *zero* files were older than 14
# days. Age-based retention works and needs nothing from us.
#
# What this adds is a ceiling on the rate. Two weeks of the crash loops being
# fixed around this date left 1121 files and 1.1G, all of them inside the
# retention window and so all legitimately kept. A cap bounds that: 256M is
# still days of ordinary crashes, and a runaway loop cannot spend the disk
# before the daily cleaner next runs.
#
# Boot-count retention -- "keep the last N boots" -- is not something systemd
# offers for coredumps. Age is the only axis, and it is the better one anyway.
#
# Do not confuse the two numbers. `coredumpctl list` showed 76,171 entries
# against 1121 files, because the journal keeps a record after tmpfiles has
# vacuumed the dump itself. That is what drkonqi's "Unable to find file for pid
# ... expected at kcrash-metadata/..." means, and it is normal. Those records
# are bounded by journald, not by anything here, and are worth keeping: the
# journal is what answers "did this work before", which is lessons.md §26.
#
# settings.Coredump, not extraConfig: `systemd.coredump.extraConfig` is
# deprecated in 26.11 and errors by name, the same way systemd.sleep.extraConfig
# did.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "keep /var/lib/systemd/coredump from growing without bound";
            systemd.coredump.settings.Coredump = {
                MaxUse  = "256M";
                KeepFree = "1G";
            };
        };
}

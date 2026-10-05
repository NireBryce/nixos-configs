# A size backstop for the coredump store.
#
# What is already true without this file: systemd ships
# `d /var/lib/systemd/coredump 0755 root root 2w` in tmpfiles, and
# systemd-tmpfiles-clean.timer runs it daily. That is the retention policy.
# This is a rate ceiling instead: it bounds what a crash loop can spend
# between two daily cleanups. MaxUse stays above the worst real fortnight
# observed (1.1G); the first draft capped below it, which would have
# discarded dumps during exactly the incident they were wanted for
# (wiki/lessons-learned.md §31).
# 
# settings.Coredump, not extraConfig: `systemd.coredump.extraConfig` is
# deprecated in 26.11 and errors by name, the same way systemd.sleep.extraConfig
# did.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # ceiling, not retention -- see header
            systemd.coredump.settings.Coredump = {
                MaxUse   = "2G";
                KeepFree = "1G";
            };
        };
}

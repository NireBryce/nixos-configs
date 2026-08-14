# A size backstop for the coredump store.
#
# What is already true without this file: systemd ships
# `d /var/lib/systemd/coredump 0755 root root 2w` in tmpfiles, and
# systemd-tmpfiles-clean.timer runs it daily.
# 
# settings.Coredump, not extraConfig: `systemd.coredump.extraConfig` is
# deprecated in 26.11 and errors by name, the same way systemd.sleep.extraConfig
# did.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # keep /var/lib/systemd/coredump from growing without bound
            systemd.coredump.settings.Coredump = {
                MaxUse   = "2G";
                KeepFree = "1G";
            };
        };
}

# tenacity announces nothing over mDNS; added 2026-09-27. It joins whatever
# Wi-Fi it's near, and avahi.nix's publish block would announce its hostname
# and addresses there. Nothing on its LAN side takes connections anyway
# (ssh-tailnet-only-tenacity.nix, lan-ports-closed-tenacity.nix), so
# `nire-tenacity.local` had nothing to lead to -- use `ts-tenacity`.
#
# Resolving other hosts' `.local` names still works: nssmdns4 and the daemon
# stay on, and UDP 5353 stays open for the replies. publish.enable = false
# renders `disable-publishing=yes`, which also covers the workstation and
# user-service records.
{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    flake.modules.nixos.${moduleName} = {
        # # description = "tenacity: mDNS resolve-only, publishes nothing";
        services.avahi.publish.enable = lib.mkForce false;
    };
}

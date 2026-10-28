# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: tenacity announces nothing over mDNS; added 2026-09-27. It joins
# whatever Wi-Fi it's near, and avahi.nix's publish block would announce its
# hostname and addresses there. Nothing on its LAN side takes connections anyway
# (ssh-tailnet-only-tenacity.nix, lan-ports-closed-tenacity.nix), so
# `nire-tenacity.local` had nothing to lead to -- use `ts-tenacity`.
#
# Resolving other hosts' `.local` names still works: nssmdns4 and the daemon
# stay on, and UDP 5353 stays open for the replies. disable-publishing = true
# renders `disable-publishing=yes`, which also covers the workstation and
# user-service records.
{ lib, ... }:
{
    nixos = {
        services.avahi.settings.publish.disable-publishing = lib.mkForce true;
    };
}

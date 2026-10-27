# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# The persistence half of vpn.nix, same shape and same gate as
# tailscale-persist.nix (read its header for why restore-root is the gate).
#
# /etc/mullvad-vpn holds the daemon's account login, device registration and
# settings; without this, durandal and tenacity log out of Mullvad on every
# boot and register a fresh device each time, eating the account's device
# slots. /var/cache/mullvad-vpn (relay list) is left to rebuild.
#
# Neither directory existed on durandal when this was added (2026-09-26), so
# the first activation has no live file to collide with -- unlike
# networkmanager-persist.nix's secret_key.
{ inputs, ... }:
{
    nixos = { config, ... }:
        inputs.self.lib.persist.persistIfImpermanent config {
            directories = [ "/etc/mullvad-vpn" ];
        };
}

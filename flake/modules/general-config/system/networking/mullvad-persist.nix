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
{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    flake.modules.nixos.${moduleName} = { config, lib, ... }:
        lib.mkIf (config.boot.initrd.systemd.services ? restore-root) {
            environment.persistence."/persist".directories = [ "/etc/mullvad-vpn" ];
        };
}

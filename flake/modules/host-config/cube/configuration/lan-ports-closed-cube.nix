# KDE Connect and Steam's LAN ports stay closed on cube, a homelab box with
# no use for either on the LAN; added 2026-09-27. durandal keeps them open.
# Same mechanism as lan-ports-closed-tenacity.nix, which has the full account:
# programs.kdeconnect's only effects are the package (the Home Manager
# kdeconnect service installs it too) and 1714-1764 opened unconditionally,
# and the two Steam switches are gaming.nix's. Both still reach cube over
# the tailnet (`tailscale0` is trusted, networking.nix).
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "cube: KDE Connect and Steam LAN ports closed; tailnet only";
            programs.kdeconnect.enable = lib.mkForce false;

            programs.steam = {
                remotePlay.openFirewall                = lib.mkForce false;
                localNetworkGameTransfers.openFirewall = lib.mkForce false;
            };
        };
}

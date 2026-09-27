# KDE Connect and Steam's LAN ports stay closed on tenacity, which joins
# whatever Wi-Fi it's near. Same idea as ssh-tailnet-only-tenacity.nix next
# door; added 2026-09-26.
#
# Both still work over the tailnet: `tailscale0` is a trusted interface
# (networking.nix), so peers reach any port with no rule. What goes is LAN
# broadcast discovery -- add the peer by its tailnet name/IP in the KDE
# Connect app, and Steam Remote Play finds hosts through the Steam account
# rather than broadcast.
#
# KDE Connect: nixpkgs' programs.kdeconnect has no firewall switch; enabling
# it opens 1714-1764 unconditionally. Its only other effect is installing the
# package, which the Home Manager services.kdeconnect (kde-connect.nix) also
# does while running the daemon -- so turning the NixOS half off here loses
# only the ports.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "tenacity: KDE Connect and Steam LAN ports closed; tailnet only";
            programs.kdeconnect.enable = lib.mkForce false;

            programs.steam = {
                remotePlay.openFirewall                = lib.mkForce false;
                localNetworkGameTransfers.openFirewall = lib.mkForce false;
            };
        };
}

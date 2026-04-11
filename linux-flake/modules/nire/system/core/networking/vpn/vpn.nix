{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.system._.${moduleName}.nixos = {
        environment.systemPackages = with pkgs; [ 
            mullvad-vpn
            tailscale                   # TODO: move to module
        ];
    };
}

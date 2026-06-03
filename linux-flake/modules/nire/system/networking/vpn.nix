{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.nixos.${moduleName} = {
            environment.systemPackages = with pkgs; [
                mullvad-vpn
                tailscale # TODO: move to module
            ];
        };
    };
}

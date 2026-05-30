{ 
    perSystem = {lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            system.stateVersion = lib.mkDefault "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        };
    };
}

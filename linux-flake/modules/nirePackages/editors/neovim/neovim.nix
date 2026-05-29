{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # neovim - it's like vim but heavier
            home.packages = with pkgs; [ neovim ];
        };
    };
}

{ 
    perSystem = {lib, pkgs, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { 
            # # description = "neofetch replacement https://github.com/hykilpikonna/HyFetch";
            home.packages = with pkgs; [
                hyfetch
            ];
        };
    };
}

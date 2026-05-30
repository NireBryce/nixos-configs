{ 
    perSystem = {pkgs, lib, ...}:
    let
      moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.homeManager.${moduleName} = {
            # description ="kanata - input-level keybinding, platform independent";
            home.packages = with pkgs; [
                kanata
            ];
        };
    };
}

{ 
    perSystem = {lib, pkgs, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { 
            # # description = "yaml jq https://github.com/mikefarah/yq";
            home.packages = with pkgs; [
                yq-go
            ];
        };
    };
}

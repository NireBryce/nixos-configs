{ 
    perSystem = {lib, pkgs, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
          # # description = "jq https://github.com/stedolan/jq";
            home.packages = with pkgs; [
                jq
            ];
        };
    };
}

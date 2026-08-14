{ lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            imports = [
                inputs.nix-index-database.homeModules.default
            ];
            # these might be hm-only
            programs.nix-index.enable = true;
            programs.nix-index.enableFishIntegration = true;
            programs.nix-index-database.comma.enable = true;
        };
}

{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # note: this is also installed as a system package, does that matter?
            home.packages = with pkgs; [ 
                firefox 
            ];
        };
}

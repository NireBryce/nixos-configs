{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
        # # description = "provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/";
            home.packages = with pkgs; [
                ldns
            ];
        };
}

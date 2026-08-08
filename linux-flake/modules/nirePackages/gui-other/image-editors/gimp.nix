{ lib, ... }:
    let
      moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # # description = "gimp - the GNU Image Manipulation Program. https://www.gimp.org";
            home.packages = with pkgs; [
                gimp
            ];
        };
}

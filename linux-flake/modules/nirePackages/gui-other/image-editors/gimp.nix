{ lib, ... }:
    let
      moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # meta.platforms excludes aarch64-darwin. The official GIMP.app is
            # what people actually use on macOS; add it as a homebrew cask in
            # nire/macos/homebrew/homebrew.nix if wanted on nire-lysithea.
            # # description = "gimp - the GNU Image Manipulation Program. https://www.gimp.org";
            home.packages = with pkgs; [
                gimp
            ];
        };
}

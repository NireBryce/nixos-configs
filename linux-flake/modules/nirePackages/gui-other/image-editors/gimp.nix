{ lib, ... }:
    let
      moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
            # nixpkgs' gimp does not build for aarch64-darwin (meta.platforms
            # excludes it), same class of failure as libre-office.nix and
            # vlc.nix. The official GIMP.app is what people actually use on
            # macOS; add it as a homebrew cask in nire/macos/homebrew/homebrew.nix
            # if wanted on nire-lysithea.
            lib.mkIf (!pkgs.stdenv.isDarwin) {
            # # description = "gimp - the GNU Image Manipulation Program. https://www.gimp.org";
            home.packages = with pkgs; [
                gimp
            ];
        };
}

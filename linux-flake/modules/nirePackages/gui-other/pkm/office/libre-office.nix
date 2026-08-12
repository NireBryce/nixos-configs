{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # nixpkgs' libreoffice-qt does not build for aarch64-darwin at all
        # (pkgs.meta.platforms excludes it outright, same class of failure as
        # the linux-utils/ packages -- see elly-home-manager.nix). On macOS the
        # official app is what people actually use; add it as a homebrew cask
        # in nire/macos/homebrew/homebrew.nix if it is wanted on nire-lysithea,
        # rather than trying to make this package work there.
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }: lib.mkIf (!pkgs.stdenv.isDarwin) {
            # # description = "libreoffice - office productivity software https://www.libreoffice.org/";
            home.packages = with pkgs; [
                libreoffice-qt
            ];
        };
}

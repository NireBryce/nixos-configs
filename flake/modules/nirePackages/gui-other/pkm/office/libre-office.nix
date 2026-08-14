{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # meta.platforms excludes aarch64-darwin. On macOS the official app is
        # what people actually use; add it as a homebrew cask in
        # nire/macos/homebrew/homebrew.nix if it is wanted on nire-lysithea,
        # rather than trying to make this package work there.
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # libreoffice - office productivity software https://www.libreoffice.org/
            home.packages = with pkgs; [
                libreoffice-qt
            ];
        };
}

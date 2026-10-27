# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    # meta.platforms excludes aarch64-darwin. On macOS the official app is
    # what people actually use; add it as a homebrew cask in
    # general-config/macos/homebrew/homebrew.nix if it is wanted on nire-lysithea,
    # rather than trying to make this package work there.
    homeManager = { pkgs, ... }: {
        # libreoffice - office productivity software https://www.libreoffice.org/
        home.packages = with pkgs; [
            libreoffice-qt
        ];
    };
}

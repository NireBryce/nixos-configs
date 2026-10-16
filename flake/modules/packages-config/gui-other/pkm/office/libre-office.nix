# Module file: named after this file; why it looks this way: wiki/module-files.md
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

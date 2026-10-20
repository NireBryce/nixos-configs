# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # meta.platforms excludes aarch64-darwin. The official VLC.app is
        # what people actually use on macOS; add it as a homebrew cask in
        # general-config/macos/homebrew/homebrew.nix if wanted on nire-lysithea.
        # vlc media player
        home.packages = with pkgs; [
            vlc
        ];
    };
}

# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # A Linux-only Electron build; meta.platforms excludes
        # aarch64-darwin. The official GitHub Desktop app is what people
        # actually use on macOS; add it as a homebrew cask in
        # general-config/macos/homebrew/homebrew.nix if wanted on nire-lysithea.
        home.packages = with pkgs; [
            github-desktop
        ];
    };
}

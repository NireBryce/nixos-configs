# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # meta.platforms excludes aarch64-darwin. The official GIMP.app is
        # what people actually use on macOS; add it as a homebrew cask in
        # general-config/macos/homebrew/homebrew.nix if wanted on nire-lysithea.
        # gimp - the GNU Image Manipulation Program. https://www.gimp.org
        home.packages = with pkgs; [
            gimp
        ];
    };
}

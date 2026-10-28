# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # package summary: gimp -- GNU Image Manipulation Program, raster image editor
        # meta.platforms excludes aarch64-darwin. The official GIMP.app is
        # what people actually use on macOS; add it as a homebrew cask in
        # general-config/macos/homebrew/homebrew.nix if wanted on nire-lysithea.
        # gimp - the GNU Image Manipulation Program. https://www.gimp.org
        home.packages = with pkgs; [
            gimp
        ];
    };
}

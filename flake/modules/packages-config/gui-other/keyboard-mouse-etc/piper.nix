# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # package summary: piper -- GTK frontend to libratbag for gaming mouse settings
        # A libratbag/udev frontend, so Linux-only with no macOS
        # equivalent; meta.platforms excludes aarch64-darwin.
        # piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper
        home.packages = with pkgs; [
            piper
        ];
    };
}

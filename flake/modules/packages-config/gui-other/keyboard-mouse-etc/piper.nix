# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # A libratbag/udev frontend, so Linux-only with no macOS
        # equivalent; meta.platforms excludes aarch64-darwin.
        # piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper
        home.packages = with pkgs; [
            piper
        ];
    };
}

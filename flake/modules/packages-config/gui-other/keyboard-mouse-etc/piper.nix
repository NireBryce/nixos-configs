# dirs-as-categories: the module is named after this file; its categories are the folders above it
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

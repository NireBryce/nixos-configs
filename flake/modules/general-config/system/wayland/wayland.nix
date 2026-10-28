# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    nixos = { pkgs, ... }: {

        programs.xwayland.enable = true;

        environment.systemPackages = with pkgs; [
            wl-clipboard # clipboard in wayland                      https://github.com/bugaevc/wl-clipboard
            wl-clipboard-x11 # clipboard in xwayland                     https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=wl-clipboard
            wayland-utils # `wayland-info`                            https://gitlab.freedesktop.org/wayland/wayland-utils
            egl-wayland # who knows what this is for                https://github.com/NVIDIA/egl-wayland/
        ];
    };
}

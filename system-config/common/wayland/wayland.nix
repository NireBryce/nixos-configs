{ 
    pkgs, 
    ... 
}: 
{
    environment.systemPackages = with pkgs;[ 
        #todo: put wayland pkgs in system cfg
        wl-clipboard                  # clipboard in wayland                      https://github.com/bugaevc/wl-clipboard
        wl-clipboard-x11              # clipboard in xwayland                     https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=wl-clipboard
        wayland-utils                 # `wayland-info`                            https://gitlab.freedesktop.org/wayland/wayland-utils
        egl-wayland                   # who knows what this is for                https://github.com/NVIDIA/egl-wayland/
    ];
}

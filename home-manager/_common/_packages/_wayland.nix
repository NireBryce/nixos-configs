{pkgs, ...}:
{
  home.packages = with pkgs; [

  # Wayland
    wl-clipboard-x11          # clipboard in wayland
    wl-clipboard              # clipboard in wayland
    wayland-utils
    egl-wayland               # iirc this leads to better game performance but idr.  wine might need it
  ];
}

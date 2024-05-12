{pkgs, config, lib ...}:
{
  # TODO: move this into graphical even though the clipboard is technically for CLI things
  options = {
    _wayland.enable = lib.mkEnableOption "Enables Wayland packages";
  }
  config = lib.mkIf config._wayland.enable {
    home.packages = with pkgs; [
    # Wayland
      wl-clipboard-x11          # clipboard in wayland
      wl-clipboard              # clipboard in wayland
      wayland-utils
      egl-wayland               # iirc this leads to better game performance but idr.  wine might need it
    ];
  };
}

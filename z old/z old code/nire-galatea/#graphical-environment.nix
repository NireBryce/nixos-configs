{ ... }:
{
# Enable the X11 windowing system.
  # TODO: x11/wayland switch
  services.xserver.enable = true;

# Enable the GNOME Desktop Environment.
  #TODO: variablize so it's a choice of DM and WM
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;
}

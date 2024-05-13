# Graphical environment settings including window manager
{ config, lib, ... }:
{
  config = lib.mkIf config._gui.enable {
    # Enable the windowing system.
    services.xserver.enable = true;
    
    # TODO: Fix this
    # services.wayland.enable = lib.mkDefault true;

    # Enable the KDE Desktop Environment and set wayland.
    services.displayManager.sddm.wayland.enable = lib.mkDefault true;
    services.desktopManager.plasma6.enable = lib.mkDefault true;


    # services.displayManager.defaultSession = "plasmawayland"; # Plasma 5
    services.displayManager.defaultSession = lib.mkDefault "plasma"; # plasma 6
    
    # make GTK apps obey theme settings
    programs.dconf.enable = lib.mkDefault true;
  };
}

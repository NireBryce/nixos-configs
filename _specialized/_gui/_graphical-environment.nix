# Graphical environment settings including window manager
{ ... }:
{
  # Enable the X11 windowing system.
    #TODO: x11/wayland switch
    services.xserver.enable = true;

  # Enable the KDE Desktop Environment and set wayland.
    #TODO: variablize so it's a choice of DM and WM
    services.xserver.displayManager.sddm.wayland.enable = true;
    services.xserver.desktopManager.plasma6.enable = true;


    # services.xserver.displayManager.defaultSession = "plasmawayland"; # Plasma 5
    services.xserver.displayManager.defaultSession = "plasma"; # plasma 6
    
  # make GTK apps obey theme settings
    #TODO: this only half works 
    programs.dconf.enable = true;
}

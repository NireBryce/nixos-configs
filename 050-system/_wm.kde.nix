{ 
  lib,
  config,
  ...
}:

# gui metapackage
{
  options = {
    wm-kde.enable = lib.mkEnableOption "Enable KDE Window Manager";
  };
  config = lib.mkIf config.wm-kde.enable {
    # WiFi
    networking.networkmanager.enable = true;  # Needs to be 'true' for KDE networking

    # Enable the windowing system.
    services.xserver.enable = true;

    # Enable the KDE Desktop Environment and set wayland.
    services.displayManager.sddm.wayland.enable =  true;
    services.displayManager.defaultSession = "plasma";        # plasma 6
    services.desktopManager.plasma6.enable =  true;
    
    # make GTK apps obey theme settings
    programs.dconf.enable = true;
  };
  
}

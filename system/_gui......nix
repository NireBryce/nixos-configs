{ ... }:

# gui metapackage
{
  # Enable the windowing system.
  services.xserver.enable = true;
  
  # TODO: this is supposedly done by plasma but let's make it here
  # services.wayland.enable = lib.mkDefault true;

  # Enable the KDE Desktop Environment and set wayland.
  services.displayManager.sddm.wayland.enable =  true;
  services.desktopManager.plasma6.enable =  true;


  # services.displayManager.defaultSession = "plasmawayland"; # Plasma 5
  services.displayManager.defaultSession = "plasma"; # plasma 6
  
  # make GTK apps obey theme settings
  programs.dconf.enable = true;
}

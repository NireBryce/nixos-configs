{ 
  ...
}:

# gui metapackage
{

  # WiFi
  networking.networkmanager.enable = true;  # Needs to be 'true' for KDE networking

  # Enable the windowing system.
  services.xserver.enable = true;

  # Enable the KDE Desktop Environment and set wayland.
  services.displayManager.sddm.enable =  true;
  services.displayManager.sddm.wayland.enable =  true;
  services.displayManager.defaultSession = "plasma";        # TODO: remove this, it's meant to select for plasma6 but plasma 6 is the default now
  services.desktopManager.plasma6.enable =  true;
  
  # make GTK apps obey theme settings
  programs.dconf.enable = true;

  # https://wiki.nixos.org/wiki/KDE
}

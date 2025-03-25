{ 
  pkgs,
  lib,
  ...
}:


{

  services.xserver.enable = true;

  # Enable the KDE Desktop Environment and set wayland.
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.defaultSession = "plasma";        # TODO: remove this, it's meant to select for plasma6 but plasma 6 is the default now
  services.desktopManager.plasma6.enable = true;
  

  # WiFi
  networking.networkmanager.enable = lib.mkDefault true;  # Needs to be 'true' for KDE networking

  
  # make GTK apps obey theme settings
  programs.dconf.enable = true;

  # fix electron fonts? https://github.com/electron/electron/issues/31797
  environment.systemPackages = with pkgs; [
    kdePackages.xdg-desktop-portal-kde
    kdePackages.spectacle         # screenshot tool                          https://invent.kde.org/graphics/spectacle
    kdePackages.konqueror         # one of the best `info` file pagers        https://invent.kde.org/network/konqueror
    kdePackages.qttools
    kdePackages.partitionmanager
    kdePackages.kcharselect        # symbol picker, may need to be kdePackages.kcharselect
  ];

  environment.sessionVariables = {
    GTK_USE_PORTAL = 1;  # TODO: what does this do
  };

  # https://wiki.nixos.org/wiki/KDE
}

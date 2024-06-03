{
  lib,
  ...
}:

{ 
  imports = [
      ./_sys.disk.WARN.impermanence.nix # this will delete /root on boot
      ./_sys.packages.nix # system packages
      ./_sys.sec.security.nix # security modules
      ./_sys.sound.nix     # sound
      ./_sys.shells.nix     # shells
      ./_sys.wm.kde.nix        # KDE
  ];

  wm-kde.enable = lib.mkDefault true; # Move this flag to user/machine configs
  environment.pathsToLink = [ # This determines what to add to /run/current-system/sw, generally defined elsewhere
    
  ];
# nix settings metapackage
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # WiFi
  networking.networkmanager.enable = true;  # Needs to be 'true' for KDE networking
  # Locale
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  time.timeZone = lib.mkDefault "America/New_York"; 

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # Bluetooth
  hardware.bluetooth.powerOnBoot = true;
  hardware.bluetooth.enable =  true;
  hardware.bluetooth.settings = {
    General = {
      FastConnectable = true;
      DiscoverableTimeout =  60;  # seconds
      PairableTimeout = 60;       # seconds
    };
  };
}



# TODO: do nix automatic garbage collection https://www.youtube.com/watch?v=uS8Bx8nQots 

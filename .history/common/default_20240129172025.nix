{
  configs,
  pkgs,
  ...
}:
{ 
  imports = [
    # ./acme.nix
    # need to make this not bound to a particular partition scheme
    # ./impermanence.nix
    ./users.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # wifi manager options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Needs to be 'true' for KDE networking
  
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  environment.etc.machine-id.source = /persist/etc/machine-id;
  
  # Set time zone.
  time.timeZone = "America/New_York";
  
  # i18n
  i18n.defaultLocale = "en_US.UTF-8";
  
# system packages
  # List packages installed in system profile. To search, run:
  # $ nix search <package name>
  environment.systemPackages = with pkgs; [
    coreutils
    micro # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    curl
    git
    bash
    zsh
  ];

  







}

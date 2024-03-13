# This is where the boot options live, along with other things that need to be set near then
{ ... }:
{
  imports = [ 
    ./_delete-root.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  networking.networkmanager.enable = true;  # Needs to be 'true' for KDE networking
  nixpkgs.config.allowUnfree = true;
  
  # Set time zone.
  time.timeZone = "America/New_York";
  
  # i18n
  i18n.defaultLocale = "en_US.UTF-8";
}

# Monument for fallen useful code
  # boot.loader.efi.efiSysMountPoint = "/boot";  
  # wifi manager options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

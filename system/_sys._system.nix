{ lib, ... }:

# Admin metapackage
{
  imports = [
    ./_sys.gui-environment.nix
    ./_sys.network-and-bt.nix
    ./_sys.shells.nix
    ./_sys.sound.nix
    ./_sys.sshd.nix
    ./_sys.WARN.impermanence.nix
  ];

  # Locale
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  time.timeZone = lib.mkDefault "America/New_York"; 

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
}

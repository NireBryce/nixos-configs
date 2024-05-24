{ lib, ... }:

# Admin metapackage
{
  imports = [
    ./_adm.gui-environment.nix
    ./_adm.shells.nix
    ./_adm.sshd.nix
    ./_adm.impermanence.nix
  ];

  # Locale
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  time.timeZone = lib.mkDefault "America/New_York"; 

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
}

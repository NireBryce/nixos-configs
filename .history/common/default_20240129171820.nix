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

  
}

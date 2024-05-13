{ lib, ... }:
{ 
  imports = [
    ./_firewall.nix
    ./_wifi.nix
  ];
  _wifi.enable = lib.mkDefault true; # Unlikely this will be disabled on more than specialist machines
}

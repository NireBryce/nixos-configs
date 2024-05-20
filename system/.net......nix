{ lib, ... }:
{
  imports = [ 
    ./.net.bluetooth+.nix
    ./.net.firewall+.nix
    ./.net.sshd.nix
    ./.net.wifi+.nix
  ];
  _wifi.enable = lib.mkDefault true;
  _firewall.enable = lib.mkDefault true;
  _bluetooth.enable = lib.mkDefault true;
}

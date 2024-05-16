{ lib, ... }:
{
  imports = [ 
    ./_net.bluetooth+.nix
    ./_net.firewall+.nix
    ./_net.sshd.nix
    ./_net.wifi+.nix
  ];
  _wifi.enable = lib.mkDefault true;
  _firewall.enable = lib.mkDefault true;
  _sshd.enable = lib.mkDefault true;
  _bluetooth.enable = lib.mkDefault true;
}

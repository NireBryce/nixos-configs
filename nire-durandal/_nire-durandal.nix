{ lib, ... }:
{
  imports = [
    # nix generated
      ./hardware-configuration.nix
      ./stateVersion.nix
    # TODO: Merge these
      ../_common
      ../_specialized
    # fixes
      ../_bugfixes/_suspend/_b550m-gpp0-etc.nix
  ];
  # hostname
  networking.hostName = "nire-durandal"; 
  
  _gui.enable = lib.mkForce true;
  _amdgpu.enable = lib.mkForce true;
  _steam.enable = lib.mkForce true;
  
  _bluetooth.enable = lib.mkForce true;
  _sound.enable = lib.mkForce true;
  _wifi.enable = lib.mkForce true;
  _zsa.enable = lib.mkForce true;
  _logitech.enable = lib.mkForce true;

  _impermanence.enable = lib.mkForce true;
    _delete-root.enable = lib.mkForce true;
    _system-partitions.enable = lib.mkForce true;
}

{ lib, ... }:

{ 
  imports = 
  [ 
    # Nix-generated
      ./hardware-configuration.nix
      ./stateVersion.nix

    # shared modules
      ../_common
      ../_specialized
      
      #TODO: ../specialized/_gpu/_intel.nix
      #TODO: ../specialized/_mouse/trackpoint.nix
      
  ];
# hostname
  networking.hostName = "nire-galatea"; 

  _gui.enable = lib.mkForce true;
  _impermanence.enable = lib.mkForce true;
  _bluetooth.enable = lib.mkForce true;
  _sound.enable = lib.mkForce true;
  _wifi.enable = lib.mkForce true;

  _zsa.enable = lib.mkForce false;
  _logitech.enable = lib.mkForce false;
  _amdgpu.enable = lib.mkForce false;
}




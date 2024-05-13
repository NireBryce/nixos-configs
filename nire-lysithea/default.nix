{ lib, ... }:
{ 
  imports = 
  [ 
    # nix generated
      ./hardware-configuration.nix
      ./stateVersion.nix
    
    # shared modules
      ../_common 
      ../_specialized
      #TODO: ../_specialized/_gpu/_intel.nix
      #TODO: ../_specialized/_mouse/_one-mix-3-nub.nix
      #TODO: ../_bugfixes/_suspend/_one-mix-3-sleep-crash.nix # suspect similar to b550
      
    # fixes
      ../_bugfixes/_suspend/_one-mix-3-lid-sensor.nix
  ];
# hostname
  networking.hostName = "nire-lysithea"; 
  
  _gui.enable = lib.mkForce true;
  _impermanence.enable = lib.mkForce true;
  _bluetooth.enable = lib.mkForce true;
  _sound.enable = lib.mkForce true;
  _wifi.enable = lib.mkForce true;

  _zsa.enable = lib.mkForce false;
  _amdgpu.enable = lib.mkForce false;
  _logitech.enable = lib.mkForce false;


}




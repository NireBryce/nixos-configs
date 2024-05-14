{ ... }:
{
  imports = [
    # Users
    ../_usr.elly.nix
    
    # nix generated
    ./hardware-configuration.nix
    ./stateVersion.nix

    # _def defaults
    ./__def.common.nix


    # fixes
    ../_bugfixes/_suspend/_b550m-gpp0-etc.nix
  ];
  # hostname
  networking.hostName = "nire-durandal"; 
  
  _gui.enable =  true;
  _amdgpu.enable =  true;
  _steam.enable =  true;
  
  _bluetooth.enable =  true;
  _pipewire.enable = true;
  _pipewire-bt.enable = true;
  _wifi.enable =  true;
  _firewall.enable = true;
  _zsa.enable =  true;
  _logitech.enable =  true;

  _impermanence.enable =  true;
    _delete-root.enable =  true;
    _system-partitions.enable =  true;
    
# Home manager stuff
  _sound.enable = true;
}

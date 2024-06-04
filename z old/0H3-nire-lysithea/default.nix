{ lib, ... }:
{ 
  imports = 
  [ 
    # nix generated
      ./hardware-configuration.nix
      ./stateVersion.nix
    
    # shared modules 
      ../050-system/__def.common.nix
      #TODO: ../_specialized/_mouse/_one-mix-3-nub.nix
      #TODO: ../_bugfixes/_suspend/_one-mix-3-sleep-crash.nix # suspect similar to b550
      #TODO: one mix random crash/power loss on battery or AC
      
    # fixes
      ../_bugfixes/_suspend/_one-mix-3-lid-sensor.nix
  ];
# hostname
  networking.hostName = "nire-lysithea"; 


}




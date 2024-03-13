{ config, pkgs, ... }:

let
  impermanence = builtins.fetchTarball "https://github.com/nix-community/impermanence/archive/master.tar.gz";
in
{ 
  imports = 
  [ 
    # nix generated
      ./hardware-configuration.nix
      ./stateVersion.nix
    
    # machine-specific
      ./_lysithea-users.nix
    
    # shared modules
      ../_common  # I try to keep non-CLI things out of this, so it can still be deployed to servers
      ../_specialized/_bluetooth
      ../_specialized/_gui
      ../_specialized/_mouse
      ../_specialized/_sound
      #TODO: ../_specialized/_gpu/_intel.nix
      #TODO: ../_specialized/_mouse/_one-mix-3-nub.nix
      #TODO: ../_bugfixes/_suspend/_one-mix-3-lid-sensor-wake-disable.nix
      #TODO: ../_bugfixes/_suspend/_one-mix-3-sleep-crash.nix # suspect similar to b550
  ];
  
  

# hostname
  networking.hostName = "nire-lysithea"; 


}




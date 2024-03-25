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
      ../_specialized
      ../_specialized/_gui
      #TODO: ../_specialized/_gpu/_intel.nix
      #TODO: ../_specialized/_mouse/_one-mix-3-nub.nix
      #TODO: ../_bugfixes/_suspend/_one-mix-3-sleep-crash.nix # suspect similar to b550
      
    # fixes
      ../_bugfixes/_suspend/_one-mix-3-lid-sensor.nix
  ];
  
  

# hostname
  networking.hostName = "nire-lysithea"; 


}




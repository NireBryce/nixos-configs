{ 
  # hostname
    networking.hostName = "nire-durandal"; 
  
  imports = [ 

    # nix generated
      ./hardware-configuration.nix
      ./stateVersion.nix
    # shared modules
      ../_common  # I try to keep non-CLI things out of this, so it can still be deployed to servers
      ../_specialized
      ../_specialized/_gpu/_amdgpu.nix
      ../_specialized/_mouse/_logitech_gaming.nix
    # fixes
      ../_bugfixes/_suspend/_b550m-gpp0-etc.nix
  ];
  
  # sopsPath = ./secrets.yaml;



}

  



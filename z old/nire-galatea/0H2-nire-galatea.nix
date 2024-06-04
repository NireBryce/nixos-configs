{ ... }:

{ 
  imports = 
  [ 
    # Nix-generated
      ./hardware-configuration.nix
      ../0H0-common/stateVersion.nix

    # shared modules 
      # TODO: Fix this
      ../050-system/__def.common.nix

      
      #TODO: ../specialized/_gpu/_intel.nix
      #TODO: ../specialized/_mouse/trackpoint.nix
      
  ];
# hostname
  networking.hostName = "nire-galatea"; 
}




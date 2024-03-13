{ config, pkgs, ... }:

let
  impermanence = builtins.fetchTarball "https://github.com/nix-community/impermanence/archive/master.tar.gz";
in
{ 
  imports = 
  [ 
    # Nix-generated
      ./hardware-configuration.nix
      ./stateVersion.nix

    # Machine-specific
      ./_galatea-users.nix

    # shared modules
      ../_common
      ../_specialized/_bluetooth
      ../_specialized/_gui
      ../_specialized/_sound
      #TODO: ../specialized/_gpu/_intel.nix
      #TODO: ../specialized/_mouse/trackpoint.nix
      
  ];
# hostname
  networking.hostName = "nire-galatea"; 
}




{ config, pkgs, ... }:

let
  impermanence = builtins.fetchTarball "https://github.com/nix-community/impermanence/archive/master.tar.gz";
in
{ 
  # hostname
    networking.hostName = "nire-durandal"; 
  
  imports = [ 

    # nix generated
      ./hardware-configuration.nix
      ./stateVersion.nix
  ];
  
  sopsPath = ./secrets.yaml;



}

  



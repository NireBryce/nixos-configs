{ config, pkgs, ... }:

let
  impermanence = builtins.fetchTarball "https://github.com/nix-community/impermanence/archive/master.tar.gz";
in
{ 
  imports = 
  [ 
    ./hardware-configuration.nix
    ./_durandal-users.nix
    ../_common
    ../_specialized/_gpu/_amdgpu.nix
    ../_specialized/_gui
    ../_specialized/_mouse
    ../_specialized/_bugfixes/_suspend/_gpp0-etc.nix
    # ../_common/_secrets
    # ../_common/_services
  ];
  
  

# hostname
  networking.hostName = "nire-durandal"; 

  

  # don't change this
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "23.11"; # Did you read the comment?
}




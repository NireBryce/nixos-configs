{
  ...
}:

{ 
  imports = [
      ./_sys._system.nix   # system and admin
      ./_nix._nix.nix      # nix settings
      ./_pkg._packages.nix # system packages
      ./_sec._security.nix # security modules
    # ./_services
  ];

  environment.pathsToLink = [ # This determines what to add to /run/current-system/sw, generally defined elsewhere
    
  ];
}

# TODO: do nix automatic garbage collection https://www.youtube.com/watch?v=uS8Bx8nQots 

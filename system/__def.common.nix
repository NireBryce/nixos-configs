{
  ...
}:

{ 
  #TODO: document `+` notation for if it has a .enable toggle
  #TODO: also document .. notation for 'default.nix' style behavior in a flat directory
  imports = [
      ./_adm......nix # admin
      ./_net......nix # network
      ./_nix......nix # nix settings
      ./_pkg......nix # system packages
      ./_snd......nix # sound
      ./_sec......nix # secrets

    # ./_services
  ];

  environment.pathsToLink = [ # This determines what to add to /run/current-system/sw, generally defined elsewhere
    
  ];
}

# TODO: do nix automatic garbage collection https://www.youtube.com/watch?v=uS8Bx8nQots 

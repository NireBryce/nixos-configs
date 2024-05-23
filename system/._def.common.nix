{lib, ...}:
{ 
  #TODO: document `+` notation for if it has a .enable toggle
  #TODO: also document .. notation for 'default.nix' style behavior in a flat directory
  imports = [
      ./.adm......nix # admin
      ./.gam......nix # games
      ./.gpu......nix # gpu
      ./.gui......nix # gui
      ./.ipr......nix # impermanence 
      ./.kb......nix  # keyboard
      ./.mou......nix # mouse
      ./.net......nix # network
      ./.nix......nix # nix settings
      ./.pkg......nix # system packages
      ./.sec......nix # secrets

    # ./_services
  ];

  environment.pathsToLink = [ # This determines what to add to /run/current-system/sw, generally defined elsewhere
    
  ];
}

# TODO: do nix automatic garbage collection https://www.youtube.com/watch?v=uS8Bx8nQots 

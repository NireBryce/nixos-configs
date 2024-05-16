{lib, ...}:
{ 
  #TODO: document `+` notation for if it has a .enable toggle
  #TODO: also document .. notation for 'default.nix' style behavior in a flat directory
  imports = [
      ./_adm......nix # admin
      ./_gam......nix # games
      ./_gpu......nix # gpu
      ./_gui......nix # gui
      ./_ipr......nix # impermanence 
      ./_kb......nix  # keyboard
      ./_mou......nix # mouse
      ./_net......nix # network
      ./_nix......nix # nix settings
      ./_pkg......nix # packages
      ./_usr......nix # user
      ./_sec......nix # secrets
      ./_snd......nix # sound

    
    # ./_services
  ];

  # TODO: Documentation, and make these switches different
  _wifi.enable = lib.mkDefault true;
  _firewall.enable = lib.mkDefault true;

  _amdgpu.enable = lib.mkDefault true;
  
  _steam.enable = lib.mkDefault true;
  
  _logitech.enable = lib.mkDefault true;
  
  _bluetooth.enable = lib.mkDefault true;
  
  _zsa.enable = lib.mkDefault true;

  _impermanence.enable = lib.mkDefault true;
    _delete-root.enable = lib.mkDefault true;
    _system-partitions.enable = lib.mkDefault true;

  # TODO: headless module that sets these falsefor headless machines
  _gui.enable = lib.mkDefault true;
  
  _pipewire.enable = lib.mkDefault true;
    _pipewire-bt.enable = lib.mkDefault true;
  

}

# TODO: do nix automatic garbage collection https://www.youtube.com/watch?v=uS8Bx8nQots 

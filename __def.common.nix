{lib, ...}:
{ 
  imports = [
    # _adm admin
      ./_adm.boot.nix
      ./_adm.locale.nix
      ./_adm.shells.nix
    # _gam games
      ./_gam.steam+.nix
    # _gpu gpu
      ./_gpu.amdgpu+.nix
    # _gui gui
      ./_gui.gui+.nix
    # _ipr impermanence
      ./_ipr._impermanence+.nix
      ./_ipr.delete-root+.nix
      ./_ipr.system-partitions+.nix
    # _kb keyboard
      ./_kb.zsa+.nix
    # _mou mouse
      ./_mou.logitech+.nix
    # _net network
      ./_net.bluetooth+.nix
      ./_net.firewall+.nix
      ./_net.sshd.nix
      ./_net.wifi+.nix  # TODO: document `+` notation for if it has a .enable toggle
    # _nix nix
      ./_nix.nix-settings.nix
    # _pkg packages
      ./_pkg._packages.nix
      ./_pkg.font.nix
      ./_pkg.linux-crisis-utilities.nix
    # _sec secrets
    # _snd sound
      ./_sec.sops.nix
      ./_snd.pipewire-bt+.nix
      ./_snd.pipewire+.nix

    
    # ./_services
  ];

  # TODO: Documentation
  _wifi.enable = lib.mkDefault true;
  _firewall.enable = lib.mkDefault true;

  _amdgpu.enable = lib.mkDefault false;
  
  _steam.enable = lib.mkDefault false;
  
  _logitech.enable = lib.mkDefault false;
  
  _bluetooth.enable = lib.mkDefault false;
  
  _zsa.enable = lib.mkDefault false;

  _impermanence.enable = lib.mkDefault false;
    _delete-root.enable = lib.mkDefault false;
    _system-partitions.enable = lib.mkDefault false;

  # TODO: headless module that sets these falsefor headless machines
  _gui.enable = lib.mkDefault true;
  
  _pipewire.enable = lib.mkDefault true;
    _pipewire-bt.enable = lib.mkDefault true;
  

}

# TODO: do nix automatic garbage collection https://www.youtube.com/watch?v=uS8Bx8nQots 

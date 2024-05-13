{ lib, config, ...}:
{ 
  options = {
    _sound.enable = lib.mkEnableOption "Enables sound settings";
  };
  config = lib.mkIf config._sound.enable {  
    imports = [ 
      ./_bluetooth-sound.nix
      ./_pipewire.nix
    ];
  };
}

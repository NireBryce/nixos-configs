{ lib, ...}:
{ 
  options = {
    _sound.enable = lib.mkEnableOption "Enables sound settings";
  };  
  imports = [ 
    ./_bluetooth-sound.nix
    ./_pipewire.nix
  ];

}

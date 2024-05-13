{lib, ...}:
{ 
  options = {
    _gui.enable = lib.mkEnableOption "Enables GUI settings";
  };
  imports = [
    ./_graphical-environment.nix
  ];
}

{lib, config}:
{ 
  options = {
    _gui.enable = lib.mkEnableOption "Enables GUI settings";
  };
  config = lib.mkIf config._gui.enable {
    imports = [
      ./_graphical-environment.nix
      ./_steam.nix
    ];
  };
}

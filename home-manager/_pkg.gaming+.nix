{ pkgs, lib, config, ... }: 
{ 
  options = {
    _hm-gaming.enable = lib.mkEnableOption "Enables gaming packages";
  };
  config = lib.mkIf config._hm-gaming.enable {
    home.packages = with pkgs; [
      # game launchers
      lutris

      # mod managers
      r2modman
      

      # proton
      protonup-qt               # proton installer/updater
      protontricks
    
      # wine
      wineWowPackages.waylandFull

      # logitech mouse config
      piper                     # logitech mouse manager https://github.com/soxoj/piper

      # comms
      teamspeak_client # ts3

      # Record
      obs-studio

      # Steam
      steamtinkerlaunch

      # video
      # TODO: check if these can be moved to nix config steam
      glfw
      dxvk
      

    ];
  };
}

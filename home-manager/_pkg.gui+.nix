{pkgs, lib, config, ...}:
{
  #TODO: maybe sort into base and optional 
  options = {
    _hm-gui.enable = lib.mkEnableOption "Enables GUI packages";
  };
  config = lib.mkIf config._hm-gui.enable {

    fonts.fontconfig.enable = true; 

    home.packages = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" ]; })

      # browsers
        kdePackages.konqueror   

      # comms
        cinny-desktop           # matrix client
        telegram-desktop
        discord
        wire-desktop
        signal-desktop
        keybase-gui
        keybase
        zoom-us

      # text input
        emote
          
      # remote
        input-leap
          
      # media
        vlc                     # video player

      # sound
        qpwgraph                # sound mixer

      # image editing
        gimp                    # image editor

      # keyboard config
        qmk                     # qmk keyboard manager https://github.com/qmk/qmk_firmware

      # gui system utilities
        # vulkan-tools
        glxinfo
        clinfo

      # dev
        vscode-fhs              # vscode
        github-desktop          # github-desktop

      # productivity
        obsidian
        libreoffice-qt          # office
      
      # terminal
        kitty
        kitty-img
    
    ];
  };
}

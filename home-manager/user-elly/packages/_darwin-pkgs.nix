{ 
  pkgs,
  ...
}:

{
  # Darwin GUI packages
    home.packages = with pkgs; [
        # discord
    ];
  
    homebrew = {
        enable = true;
        onActivation.cleanup = "uninstall"; # Uninstall packages not declared in nix config 
        taps  = [];
        brews = [ 
            "gifski"
            "magic-wormhole"
        ];
        casks = [ 
            "angry-ip-scanner"
            "app-cleaner"
            "balenaetcher"
            "betterdisplay"
            "bettertouchtool"
            "bitwarden"
            "cd-to"
            "cleanshot"
            "daisydisk"
            "dash@6"
            "discord"
            "dropshare"
            "file-juicer"
            "gimp"
            "github"
            "hammerspoon"
            "iina"
            "istat-menus"
            "jordanbaird-ice"
            "karabiner-elements"
            "keka"
            "keyboard-maestro"
            "kitty"
            "latest"
            "losslesscut"
            "lulu"
            "mist"
            "name-mangler"
            "netnewswire"
            "obsidian"
            "openinterminal"
            "orbstack"
            "pacifist"
            "raspberry-pi-imager"
            "raycast"
            "rectangle"
            "rocket"
            "sloth"
            "steam"
            "tailscale"
            # "temurin@11" # jdk for something else?
            "the-unarchiver"
            "transmit"
            "unicodechecker"
            "utm"
            "visual-studio-code"
            "whisky"
            "xcodes"
            "xscope"
            "zoom"
            "google-chrome"
        ];
    };  

}

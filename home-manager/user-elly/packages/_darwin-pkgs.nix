{ 
  pkgs,
  ...
}:

{
  # Darwin packages, for some reason home.packages does not install them, googling found nothing
    environment.systemPackages = with pkgs; [
        # discord
        just
        fish
    ];
  
    homebrew = {
        enable = true;
        onActivation.cleanup = "uninstall"; # Uninstall packages not declared in nix config 
        taps  = [];
        brews = [ 
            "gifski"                # gif creator/converter
            "magic-wormhole"        # easy secure point-to-point file transfer
        ];
        casks = [ # TODO: describe each
            "angry-ip-scanner"      # does what it says on the tin
            "app-cleaner"           # also does what it says on the tin
            "balenaetcher"          # disk image writer
            "betterdisplay"         # better display settings
            "bettertouchtool"       # touchbar configurator, but also more 
            "bitwarden"             # password manager
            "cd-to"                 # TODO: dont remember
            "cleanshot"             # screenshot
            "daisydisk"             # disk usage viewer
            "dash@6"                # TODO: dont remember
            "discord"               # why do i have to use discord for everyone
            "dropshare"             # TODO: dont remember
            "file-juicer"           # TODO: dont remember
            "gimp"                  # image editor
            "github"                # github desktop
            "hammerspoon"           # automations
            "iina"                  # TODO: dont remember
            "istat-menus"           # menu bar stat indicators
            "jordanbaird-ice"       # TODO: dont remember
            "karabiner-elements"    # keyboard rebinder, look into kanata instead
            "keka"                  # TODO: dont remember
            "keyboard-maestro"      # TODO: dont remember
            "kitty"                 # terminal emulator
            "latest"                # TODO: dont remember
            "losslesscut"           # TODO: dont remember
            "lulu"                  # TODO: dont remember
            "mist"                  # TODO: dont remember
            "name-mangler"          # bulk rename tool
            "netnewswire"           # rss reader
            "obsidian"              # notes / PKM / wiki-like
            "openinterminal"        # context menu option for opening `finder` location in terminal
            "orbstack"              # VM/OCI manager
            "pacifist"              # TODO: dont remember
            "raspberry-pi-imager"   # lets you set some settings as you flash the pi
            "raycast"               # much better spotlight, clipboard manager
            "rectangle"             # window tiling but not a tiler
            "rocket"                # emoji menu
            "sloth"                 # TODO: dont remember
            "steam"                 # steam games library
            "tailscale"             # network tunnel
            # "temurin@11" # jdk for something else?
            "the-unarchiver"        # TODO: dont remember
            "transmit"              # TODO: dont remember
            "unicodechecker"        # TODO: dont remember
            "utm"                   # another VM thing
            "visual-studio-code"    # VSCode
            "whisky"                # `wine` for mac
            "xcodes"                # version manager for various languages (python?)
            "xscope"                # TODO: dont remember
            "zoom"                  # video conferencing
            "google-chrome"         # need for webserial and webBLE apps for devices
        ];
    };  

}

# MacOS
{
  pkgs,
  lib,
  ...
}:

{


  system.primaryUser = "elly"; # user used for darwin-rebuild

  # Used for backwards compatibility, please read the changelog before changing: `darwin-rebuild changelog`
    system.stateVersion = 4;
    nixpkgs.hostPlatform = "aarch64-darwin";

  # nix settings
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nixpkgs.config.allowUnfree = true; 
    nix.enable = true;

  # Set Git commit hash for darwin-version.
    # system.configurationRevision = self.rev or self.dirtyRev or null;
  

  ## shells
    environment.shells = with pkgs; [
        bash
        zsh
        fish
    ];
  
  #? Make sure system completions work even with home-manager managed shells 
    environment.pathsToLink = [   
        "/share/zsh"
        "/share/bash-completion"
        "/share/fish"
    ];
  
  #? zsh is handled through home-manager
    programs.zsh.enable = true;
    programs.zsh.enableCompletion = lib.mkForce false;  # unless disabled, home-manager causes an extra compaudit

    fonts.packages = with pkgs; [
        nerd-fonts.fira-code
        nerd-fonts.iosevka
        nerd-fonts.jetbrains-mono
    ];

  ## System packages
    environment.systemPackages = with pkgs; [ # Always have an editor here
      #* System utilities
        # bash                                           # ok. i guess.
          #? Bash Plugins
            inshellisense                       # menu-complete and auto-suggest
            starship                            # theming
            blesh                               # if bash were zsh
        coreutils                                     # coreutils
        gcc                                           # gcc
        git                                           # git
        stdenv                                        # stdenv
        wget                                          # wget
        curl                                          # curl
        zoxide                                        # zoxide
        ripgrep                                       # ripgrep
        nix-output-monitor                            # `nom` nix-output-monitor  https://github.com/maralorn/nix-output-monitor
        nh                                            # nix helper                https://github.com/viperML/nh
        sops                                          # secret management
        just
        # dircolors # either not darwin or needs home manager
        starship
        just
        mask
        direnv
    # nix dev
      nixfmt
      nil
      nixd
    # python dev
      uv                            # `pyenv` but it's actually good
      ruff                          # python linter                             https://github.com/astral-sh/ruff
      # ruff-lsp                      # ruff integration with vscode              https://github.com/astral-sh/ruff-lsp
    # bash dev
      shellcheck                    # bash linter                               https://www.shellcheck.net/
      shfmt                         # bash formatter                            https://github.com/mvdan/sh
    # general utils
      diffutils                     # `diff` utils                              https://github.com/ogham/diffutils
      direnv                        # per-directory environments                https://github.com/direnv/direnv
      sqlite                        # sqlite                                    https://www.sqlite.org/
      riffdiff                      # provides `riff`, where-in-line diff       https://github.com/walles/riff
    # git                       # git                                       # git  
      gh                            # github cli                                https://github.com/cli/cli
      git                           # git scm                                   https://git-scm.com
      delta                         # `delta` - git diff                        https://github.com/dandavison/delta
      lazygit                       # TUI git interface                         https://github.com/jesseduffield/lazygit
      commitizen                    # commitizen                                https://github.com/commitizen-tools/commitizen
    # docker
      lazydocker                    # TUI docker interface                      https://github.com/jesseduffield/lazydocker
  
      entr                          # run commands when files change            https://github.com/eradman/entr
      tokei                         # count lines of code                       https://github.com/XAMPPRocky/tokei
      mprocs                        # run multiple commands in parallel         https://github.com/ogham/mprocs
        #editors
        # nvim # not darwin
        micro
        aria2                         # cli download manager                      https://aria2.github.io/
        # magic-wormhole-rs             # easy transfer arbitrary files encrypted   https://github.com/magic-wormhole/magic-wormhole.rs
        rsync                         # up hill both ways 

        # helptext
        cheat                         # cli cheatsheets                           https://github.com/cheat/cheat
        # tldr                          # better man pages 

        # multiplexers
        tmux
        zellij

        # nav
        eza
        zoxide
        mc                            # midnight commander TUI file manager       https://www.midnight-commander.org/
        yazi

        # nix
        nix-output-monitor
        nh

        # 
        ripgrep
        fd

        btop
        hyfetch

        bat
        kitty-img

        broot
        
        
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
            "audacity"              # audio editor
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
            "autodesk-fusion"       # Fusion 180 (personal featureless edition)
            "fantastical"           # Calendar Software
            "moonlight"             # moonlight game streaming (sunshine on durandal)
            "mullvadvpn"            # mullvad vpn
            "insta360-studio"       # 360 video editor
            "espanso"               # global text expansions
            "firefox"               # TODO: this might break FF it used to be system managed
            "obs"
        ];  
    };  
    








} 





# TODO: move to home-manager / fix for darwin
  # programs.nh = {                                   # `nh` nix-helper           https://github.com/viperML/nh
  #     enable = true;
  #     clean.enable = true;
  #     clean.extraArgs = "--keep-since 7d --keep 5";
  #     flake = "/Users/elly/nixos";
  #   };

    # programs.command-not-found.enable = lib.mkForce false; # conflicts with nix-index-database
# TODO: fixme for darwin
  # fonts.packages = with pkgs; [
  #   (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" "Iosevka" "JetBrainsMono" ];})  # be not afraid
  # ];
# TODO: nix-index workaround potentially deprecated refer to darwin section of flake
# $NIX_PATH
  # nix.nixPath = [                                           # make nix-index not use channels https://github.com/nix-community/nix-index/issues/167
  #   "nixpkgs=${nixpkgs}"
  #   "/nix/var/nix/profiles/per-user/root/channels"
  # ];

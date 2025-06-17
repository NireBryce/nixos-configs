# MacOS
{
  pkgs,
  lib,
  ...
}:

{
  imports = [ 
    ../home-manager/user-elly/packages/cli-pkgs/shell

  ];
  home-manager.backupFileExtension = "backup";
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
  
    programs.bash.interactiveShellInit = ''
        ${pkgs.inshellisense}/bin/inshellisense;
    '';

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
        atuin
        coreutils                                     # coreutils
        gcc                                           # gcc
        git                                           # git
        micro                                         # micro
        stdenv                                        # stdenv
        wget                                          # wget
        curl                                          # curl
        zoxide                                        # zoxide
        ripgrep                                       # ripgrep
        nix-output-monitor                            # `nom` nix-output-monitor  https://github.com/maralorn/nix-output-monitor
        nh                                            # nix helper                https://github.com/viperML/nh
        sops                                          # secret management
        just
        vscode-fhs
        dircolors
        starship
        just
        mask
        direnv
    # nix dev
      nixfmt
      nil
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
        nvim
        micro
        aria2                         # cli download manager                      https://aria2.github.io/
        # magic-wormhole-rs             # easy transfer arbitrary files encrypted   https://github.com/magic-wormhole/magic-wormhole.rs
        rsync                         # up hill both ways 

        # helptext
        cheat                         # cli cheatsheets                           https://github.com/cheat/cheat
        tldr                          # better man pages 

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
        davinci-resolve

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
    programs.kitty = {
        enable  = true;
        extraConfig = ''
            clipboard_control write-clipboard write-primary read-clipboard-ask read-primary-ask
            kitty_mod ctrl+shift

            map kitty_mod+c copy_to_clipboard
            map cmd+c       copy_or_interrupt

            map kitty_mod+v paste_from_clipboard
            map cmd+v       paste_from_clipboard
        '';
    };
    programs.micro = {
        enable = true;
        settings = {
            autoclose = false;
            backup = false;
            autosu = true;
            cursorline  = true;
            colorscheme = "dukeubuntu-tc";
            difgutter = true;
            eofnewline = true;
            fastdirty = true;
            ignorecase = false;
            keyenu = true;
            mkparents = true;
            savehistory = false;
            tabsize = 2;
            tsbstospaces = true;
            colorcolumn = 81;
            indentchar = "·";
            multiopen = "hsplit";
            parsecursor = true;
            linter = true;
            comment = true;
            tabstospaces = true;
        };
    };
    programs.fzf = {
        enable = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        enableFishIntegration   = true;
        defaultOptions = [
            "--height 40%"
            "--layout=reverse"
            "--border"
            "--inline-info"
            #todo: fix these I think they only work for bash or its expecting `vivid`
            # '' --color 'fg:#${vars.colors.base05}' ''              # Text
            # '' --color 'bg:#''${vars.colors.base00}' ''              # Background
            # '' --color 'preview-fg:#''${vars.colors.base05}' ''      # Preview window text
            # '' --color 'preview-bg:#''${vars.colors.base02}' ''      # Preview window background
            # '' --color 'hl:#''${vars.colors.base0A}' ''              # Highlighted substrings
            # '' --color 'fg+:#''${vars.colors.base0D}' ''             # Text (current line)
            # '' --color 'bg+:#''${vars.colors.base02}' ''             # Background (current line)
            # '' --color 'gutter:#''${vars.colors.base02}' ''          # Gutter on the left (defaults to bg+)
            # '' --color 'hl+:#''${vars.colors.base0E}' ''             # Highlighted substrings (current line)
            # '' --color 'info:#''${vars.colors.base0E}' ''            # Info line (match counters)
            # '' --color 'border:#''${vars.colors.base0D}' ''          # Border around the window (--border and --preview)
            # '' --color 'prompt:#''${vars.colors.base05}' ''          # Prompt
            # '' --color 'pointer:#''${vars.colors.base0E}' ''         # Pointer to the current line
            # '' --color 'marker:#''${vars.colors.base0E}' ''          # Multi-select marker
            # '' --color 'spinner:#''${vars.colors.base0E}' ''         # Streaming input indicator
            # '' --color 'header:#''${vars.colors.base05}' ''          # Header
        ];
    };

  programs.atuin = {       
        enable                  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        settings = {
            inline_height   = 10;       # search window height
            style = "compact";
            show_preview    = true;
            show_help       = true;
            secrets_filter  = true;
        };
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

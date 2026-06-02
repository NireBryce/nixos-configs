#* This defines the nire-lysithea host-specific user config for elly

# ! NOTE !
# ? Packages are currently managed via darwin.
{
  pkgs,
  ...
}:
{
  imports = [
    ./zsh.nix

  ];

  nixpkgs.config = {
                allowUnfree = true; # Disable if you don't want unfree packages
                allowUnfreePredicate = (_: true); # Workaround for https://github.com/nix-community/home-manager/issues/2942
            };
  # git
  home.file."./.gitconfig".source = ./.gitconfig;
  programs.git = {        # User-specific git config
      enable = true;
      settings = {
          alias = {
              pushall = "!git remote | xargs -L1 git push --all";
              graph = "log --decorate --oneline --graph";
              add-nowhitespace = "!git diff -U0 -w --no-color | git apply --cached --ignore-whitespace --unidiff-zero -";
          };
          user = {
              name = "Nire Bryce";
              email = "nire@computernope.net";
          };
          
          feature.manyFiles = true;
          init.defaultBranch = "main";
          gpg.format = "ssh";
      };
      signing = {
          key = "~/.ssh/id_ed25519";
          signByDefault = builtins.stringLength "~/.ssh/id_ed25519" > 0;
      };

      lfs.enable = true;
      ignores = [ ".direnv" "result" ];
  };

  # Session

  
    home.sessionVariables = { 
        EDITOR                  = "micro";
        MICRO_TRUECOLOR         = 1;
        NIXPKGS_ALLOW_UNFREE    = 1;
        PYTHONBREAKPOINT        = "ipdb.set_trace";
        COLORTERM               = "truecolor";
        PAGER                   = "less -R";
        MANPAGER                = "${pkgs.bat}/bin/bat --language man";
        LC_CTYPE                = "en_US.UTF-8";
        LS_COLORS               = "$(${pkgs.vivid}/bin/vivid generate dracula)";  # https://github.com/sharkdp/vivid
        EZA_COLORS              = "$(${pkgs.vivid}/bin/vivid generate dracula)";
        # STARSHIP_CONFIG         = "$HOME/.config/starship.toml";
        # STARSHIP_CACHE          = "$HOME/.cache/starship";
        PYTHON                  = "PYTHON";
    };
    home.sessionPath = [ 
        "/usr/local"
        "/usr/bin"
        "$HOME/bin"
        "$HOME/.local/bin"
        "$HOME/.nix-profile/bin"
        "$HOME/.zi/bin"
        "$HOME/.config/zi/bin"
        "$HOME/.cargo/bin"
        "/Users/elly/.local/bin:$PATH"
    ];

    
# TODO: mvpn keeps reinstalling itself


  ## Defaults

  home.username = "elly";
  home.homeDirectory = "/Users/elly";

  #! Do not edit. To figure this out (in-case it changes) you can comment out the line and see what version it expected.
  home.stateVersion = "22.11";

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    options = [ "--cmd x" ]; # `zi` alias interferes with z-shell/zi
  };

  programs.kitty = {
    enable = true;
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
      cursorline = true;
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
    enableZshIntegration = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
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
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    settings = {
      inline_height = 10; # search window height
      style = "compact";
      show_preview = true;
      show_help = true;
      secrets_filter = true;
    };
  };
}

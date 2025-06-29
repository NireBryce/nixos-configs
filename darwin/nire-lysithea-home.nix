#* This defines the nire-lysithea host-specific user config for elly


# ! NOTE !
# ? Packages are currently managed via darwin.
{ 
    import-tree,
	... 
}:
let 
    home-manager-user = ../home-manager/user-elly;
in {
    imports = [
        "${home-manager-user}/home-config/git-config/git-settings-elly.nix"
        "${home-manager-user}/home-config/shell-configs/zsh/zsh.nix"
        "${home-manager-user}/home-config/nix-settings.nix"
    ];
    
  ## Defaults
    nixpkgs.config = {
        allowUnfree          =     true;            # Disable if you don't want unfree packages
        allowUnfreePredicate = (_: true);           # Workaround for https://github.com/nix-community/home-manager/issues/2942
    };
    home.username            = "elly";
    home.homeDirectory       = "/Users/elly";
    
    #! Do not edit. To figure this out (in-case it changes) you can comment out the line and see what version it expected.
    home.stateVersion        = "22.11"; 



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

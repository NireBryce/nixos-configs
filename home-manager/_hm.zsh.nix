{
  self,
  pkgs,
  lib,
  ...
}:
let flakePath = self;
in {
    # Notes:
    # If you get `zsh side` errors, delete ~/.zcompdump and ~/.config/zsh/.zcompdump and run `zi update`
    # installing multiple highlighters causes "zsh_zle-highlight-buffer-p:4: permission denied error
    # in this case it was trapd00r/zsh-syntax-highlighting-filetypes which highlights more than filetypes turns out

    # TODO: replace p10k with `starship` now that p10k is in life support mode

  programs = { # zsh specific, it dedups them if they're already enabled
    dircolors.enable = true; 
    dircolors.enableZshIntegration = true;
    eza.enableZshIntegration = true;
    direnv.enableZshIntegration = true;
    zellij.enableZshIntegration = true;
    broot.enableZshIntegration = true;
    nix-index.enableZshIntegration = true;
    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultOptions = [
        "--height 40%"
        "--layout=reverse"
        "--border"
        "--inline-info"
        "--color 'fg:#\${vars.colors.base05}'"              # Text
        "--color 'bg:#\${vars.colors.base00}'"              # Background
        "--color 'preview-fg:#\${vars.colors.base05}'"      # Preview window text
        "--color 'preview-bg:#\${vars.colors.base02}'"      # Preview window background
        "--color 'hl:#\${vars.colors.base0A}'"              # Highlighted substrings
        "--color 'fg+:#\${vars.colors.base0D}'"             # Text (current line)
        "--color 'bg+:#\${vars.colors.base02}'"             # Background (current line)
        "--color 'gutter:#\${vars.colors.base02}'"          # Gutter on the left (defaults to bg+)
        "--color 'hl+:#\${vars.colors.base0E}'"             # Highlighted substrings (current line)
        "--color 'info:#\${vars.colors.base0E}'"            # Info line (match counters)
        "--color 'border:#\${vars.colors.base0D}'"          # Border around the window (--border and --preview)
        "--color 'prompt:#\${vars.colors.base05}'"          # Prompt
        "--color 'pointer:#\${vars.colors.base0E}'"         # Pointer to the current line
        "--color 'marker:#\${vars.colors.base0E}'"          # Multi-select marker
        "--color 'spinner:#\${vars.colors.base0E}'"         # Streaming input indicator
        "--color 'header:#\${vars.colors.base05}'"          # Header
      ];
    };
  };
  

  

  home.packages = with pkgs; [  # Things needed for my .zshrc
    diff-so-fancy
    zoxide
    atuin
    tree
    zi                              # zsh plugin manager
  ];
  
  programs.zsh = 
    let               
      p10k_cfg          = lib.fileContents "${flakePath}/home-manager/dotfiles/config/zsh/010-p10k.zsh";
      bindings_cfg      = lib.fileContents "${flakePath}/home-manager/dotfiles/config/zsh/initial-bindings.zsh";
      setopts_cfg       = lib.fileContents "${flakePath}/home-manager/dotfiles/config/zsh/initial-setopts.zsh";
      zstyle_cfg        = lib.fileContents "${flakePath}/home-manager/dotfiles/config/zsh/initial-zstyle.zsh";
      nix_fpath_cfg     = lib.fileContents "${flakePath}/home-manager/dotfiles/config/zsh/011-nix-fpath.zsh";
      zi_cfg            = lib.fileContents "${flakePath}/home-manager/dotfiles/config/zsh/020-zi.zsh";
      zi_plugins_cfg    = lib.fileContents "${flakePath}/home-manager/dotfiles/config/zsh/zi-plugins.zsh";
      atuin_cfg         = lib.fileContents "${flakePath}/home-manager/dotfiles/config/zsh/021-atuin.zsh";
      zellij_keys_cfg   = lib.fileContents "${flakePath}/home-manager/dotfiles/config/zsh/040-free-zellij-keys.zsh";
    in {
    enable = true;
    autocd = false;
    enableVteIntegration = true;
    autosuggestion.enable = true;
    enableCompletion = false;       # enabled through config, removing one compinit call.
    zsh-abbr.enable = true;
    
    localVariables = {
      _ZO_CMD_PREFIX="x";
    };

    # .zshrc
    
    initExtraFirst = ''
      zmodload zsh/zprof                                # zsh profiler
      #################PASSWORD ENTRY/CONFIRM DIALOGS GO ABOVE##############################
      ${p10k_cfg}                                       # Powerlevel10k instant prompt.  input above, else below
      ${bindings_cfg}                                   # keybindings from various configs
      ${setopts_cfg}                                    # setopts from the same
      ${zstyle_cfg}                                     # zstyle opts from the same
      typeset -U path cdpath fpath manpath              # TODO: magic, no idea what it does
      ${nix_fpath_cfg}                                  # tells zsh where nix lives
      autoload -U add-zsh-hook                          # TODO: Magic, no idea.
      zmodload zsh/terminfo                             # load terminfo
      WORDCHARS='*?[]~=&;!#$%^(){}<>';                  # Dont consider certain characters part of the word
    '';
    
    initExtraBeforeCompInit = ''
      ${zi_cfg}                                         # zi bootstrap
      ${zi_plugins_cfg}                                 # Zi plugins
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh        # Load p10k theme
      zicompinit                                          # zi cleanup
      autoload -Uz compinit
      compinit -C
    '';
    initExtra = ''
      ${atuin_cfg}                                      # Atuin
      ${zellij_keys_cfg}                                # Free up bindings for zellij
      disable -p '#'                                    # Necessary to run flakes, otherwise # gets expanded
    '';
    shellAliases = {
      ll  ="ls -l";
      cp  ="cp -i";                                     # Confirm before overwriting something
      cd  = "x";                                        # Empty oneletter for zoxide to not interfere with zi
      exa = "eza --icons=always";                       # back compat for one of the tools
      ls  = "eza --icons=always --header --group-directories-first --hyperlink";
      rustdevshell = "nix develop ~/nixos/dev-shells/rust#";
    };
  };
}


  # # For LS_COLORS customization options run this in shell:
  # for theme in $(vivid themes); do
  #     echo "Theme: $theme"
  #     LS_COLORS=$(vivid generate $theme)
  #     ls
  #     echo
  # done

# old code

  # dotDir=".config/zsh";
  # plugins = [
  # {
  #   name = "powerlevel10k";
  #   src = pkgs.zsh-powerlevel10k;
  #   file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
  # }
  # {
  #   name = "powerlevel10k-config";
  #   src = config/zsh-powerlevel10k; file = ".p10k.zsh";
  #   }
  # ];


# # f-sy-h is better. 
# syntaxHighlighting = {
  # enable = true;
  # # package = "";
  # highlighters = [
  #   "brackets"
  #   "pattern"
  #   "regexp"
  #   # "cursor"
  #   # "root"
  #   # "line"
  # ];
  
# };   



# history = {
#   path = "${config.xdg.configHome}/zsh/history";
#   save = 5000;
# };

# from fleek / getfleek.dev (RIP)
  # "apply-nire-durandal" = "nix run --impure home-manager/master -- -b bak switch --flake .#elly@nire-durandal";
  # "apply-nire-galatea" = "nix run --impure home-manager/master -- -b bak switch --flake .#elly@nire-galatea";
  # "apply-nire-lysithea" = "nix run --impure home-manager/master -- -b bak switch --flake .#elly@nire-lysithea";

# Whats this do? something from ancient compinit start time debugging
      # for dump in ~/.zcompdump(N.mh+24); do
      #   compinit
      # done

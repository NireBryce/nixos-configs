{ lib, config, pkgs, ... }: 
{
  # TODO: mkDefault
  options = {
    _hm-zsh.enable = lib.mkEnableOption "Enables zsh";
  };
  config = lib.mkIf config._hm-zsh.enable {
    # enable zsh-abbr if zsh is enabled
      # _zsh-abbr.enable = true; 

    # Added from Fleek (now deprecated), figure out what they do.
      # programs.zsh.profileExtra = ''
      #   [ -r ~/.nix-profile/etc/profile.d/nix.sh ] && source  ~/.nix-profile/etc/profile.d/nix.sh
      #   export XCURSOR_PATH=$XCURSOR_PATH:/usr/share/icons:~/.local/share/icons:~/.icons:~/.nix-profile/share/icons
      # '';

    # Notes:
      # If you get `zsh side` errors, delete ~/.zcompdump and ~/.config/zsh/.zcompdump and run `zi update`
      # installing multiple highlighters causes "zsh_zle-highlight-buffer-p:4: permission denied error
      # in this case it was trapd00r/zsh-syntax-highlighting-filetypes which highlights more than filetypes turns out

    programs = { # zsh specific, it dedups them if they're already enabled
      dircolors.enable = true; 
      dircolors.enableZshIntegration = true;
      eza.enableZshIntegration = true;
      # atuin.enableZshIntegration = true;
      direnv.enableZshIntegration = true;
      # fzf.enableZshIntegration = true;
      zellij.enableZshIntegration = true;
      # zoxide.enableZshIntegration = true; # done in zsh config
      broot.enableZshIntegration = true;
    };

    home.packages = with pkgs; [ # Things needed for my .zshrc
      diff-so-fancy
      zoxide
      atuin
      fzf
      tree
      zi                        # zsh plugin manager
    ];
    
    programs.zsh = {
      enable = true;
      autocd = false;
      enableVteIntegration = true;
      autosuggestion.enable = true;
      enableCompletion = false;    # Already enabled in .zshrc, this makes it do it twice.
      zsh-abbr.enable = true;
      
      localVariables = {
        _ZO_CMD_PREFIX="x";
      };

      shellAliases = {
        ll = "ls -l";
        cp = "cp -i";                              # Confirm before overwriting something
        cd = "x";                                  # Empty oneletter for zoxide to not interfere with zi
        exa = "eza --icons=always";
        ls = "eza --icons=always --header --group-directories-first";
      };

      # .zshrc
      initExtraFirst = ''
        zmodload zsh/zprof                                  # zsh profiler
        #################PASSWORD ENTRY/CONFIRM DIALOGS GO ABOVE##############################
        source $HOME/.config/zsh/010-p10k.zsh               # Powerlevel10k instant prompt.  input above, else below
        source $HOME/.config/zsh/initial-bindings.zsh       # keybindings from various configs
        source $HOME/.config/zsh/initial-setopts.zsh'       # setopts from the same
        source $HOME/.config/zsh/initial-zstyle.zsh         # zstyle opts from the same
        typeset -U path cdpath fpath manpath                # TODO: magic, no idea what it does
        source $HOME/.config/zsh/011-nix-fpath.zsh          # tells zsh where nix lives
        autoload -U add-zsh-hook                            # TODO: Magic, no idea.
        zmodload zsh/terminfo                               # load terminfo
        WORDCHARS='*?[]~=&;!#$%^(){}<>';                    # Dont consider certain characters part of the word
      '';
      
      initExtraBeforeCompInit = ''
        source $HOME/.config/zsh/020-zi.zsh                 # zi bootstrap
        source $HOME/.config/zsh/zi-plugins.zsh             # Zi plugins
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh        # Load p10k theme
        zicompinit                                          # zi cleanup
        # autoload -Uz compinit                               # TODO: break glass in case nix doesnt do this
      '';
      initExtra = ''
        source $HOME/.config/zsh/021-atuin.zsh              # Atuin
        source $HOME/.config/zsh/040-free-zellij-keys       # Free up bindings for zellij
        disable -p '#'                                      # Necessary to run flakes, otherwise # gets expanded
      '';
   };
  };
}
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

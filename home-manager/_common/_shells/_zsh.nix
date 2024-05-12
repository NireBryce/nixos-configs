{ lib, config, pkgs, ... }: 
{
  # TODO: mkEnable, mkIf zsh enabled
  options = {
    _zsh.enable = lib.mkEnableOption "Enables zsh";
  };
  config = lib.mkIf config._zsh.enable {
    # Added from Fleek (now deprecated), figure out what they do.
    programs.zsh.profileExtra = ''
      [ -r ~/.nix-profile/etc/profile.d/nix.sh ] && source  ~/.nix-profile/etc/profile.d/nix.sh
      export XCURSOR_PATH=$XCURSOR_PATH:/usr/share/icons:~/.local/share/icons:~/.icons:~/.nix-profile/share/icons
    '';

    # Notes:
      # If you get `zsh side` errors, delete ~/.zcompdump and ~/.config/zsh/.zcompdump and run `zi update`
      # installing multiple highlighters causes "zsh_zle-highlight-buffer-p:4: permission denied error
      # in this case it was trapd00r/zsh-syntax-highlighting-filetypes which highlights more than filetypes turns out

    programs = { # zsh specific, it dedups them if they're already enabled
      dircolors.enable = true; 
      dircolors.enableZshIntegration = true;
      # atuin.enableZshIntegration = true;
      direnv.enableZshIntegration = true;
      # fzf.enableZshIntegration = true;
      zellij.enableZshIntegration = true;
      # zoxide.enableZshIntegration = true; # done in zsh config
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
      enableCompletion = true;
      zsh-abbr.enable = true;
      
      localVariables = {
        _ZO_CMD_PREFIX="x";
      };
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

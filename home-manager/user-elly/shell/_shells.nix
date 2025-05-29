{
  self,
  pkgs,
  lib,
  ...
}:
let flakePath = ../../..; # TODO: fix-me if this is `self` like the rest, it causes recursion bug with home-manager being run via nix-darwin
in {
    # Notes:
    # If you get `zsh side` errors, delete ~/.zcompdump and ~/.config/zsh/.zcompdump and run `zi update`
    # installing multiple highlighters causes "zsh_zle-highlight-buffer-p:4: permission denied error
    # in this case it was trapd00r/zsh-syntax-highlighting-filetypes which highlights more than filetypes turns out

    # TO-DONE: evaluate oh-my-zsh, prezto
    #          o-m-z is too all-encompassing still, but has best support
    #          prezto not worth looking into imo because I want something stable
    #          ironically this means going back to `zi` for now

    # TODO: replace p10k with `starship` now that p10k is in life support mode

    # TODO: figure out how to make zi less fragile, or how to do zi's plugin management declaratively


    programs = { # zsh specific, if these are enabled elsewhere nix will dedupe

                
        
        
        

        
          

        
        
    };
    # end programs

    home.packages = with pkgs; [  # Things needed for my .zshrc
        diff-so-fancy
        # inshellisense
        starship
        # zoxide
        # atuin
        tree
        ruby                            # zi depends on `gem`
        nix-zsh-completions
        zsh-f-sy-h
        zsh-fzf-tab
        zsh-nix-shell
        zsh-completions
        zsh-autocomplete
        zsh-autosuggestions
        # zsh-powerlevel10k # in zi
        zsh-system-clipboard
        zsh-you-should-use
    ];

    

    programs.zsh = let               
        p10k_cfg        = lib.fileContents 
            "${flakePath}/home-manager/user-elly/dotfiles/zsh/010-p10k.zsh";
        bindings_cfg    = lib.fileContents 
            "${flakePath}/home-manager/user-elly/dotfiles/zsh/initial-bindings.zsh";
        setopts_cfg     = lib.fileContents 
            "${flakePath}/home-manager/user-elly/dotfiles/zsh/initial-setopts.zsh";
        zstyle_cfg      = lib.fileContents 
            "${flakePath}/home-manager/user-elly/dotfiles/zsh/initial-zstyle.zsh";
        zi_cfg          = lib.fileContents 
            "${flakePath}/home-manager/user-elly/dotfiles/zsh/020-zi.zsh";
        zi_plugins_cfg  = lib.fileContents 
            "${flakePath}/home-manager/user-elly/dotfiles/zsh/zi-plugins.zsh";
        zellij_keys_cfg = lib.fileContents 
            "${flakePath}/home-manager/user-elly/dotfiles/zsh/040-free-zellij-keys.zsh";
    in {
        enable                  =  true;
        autocd                  = false;
        enableVteIntegration    =  true;
        autosuggestion.enable   =  true;
        enableCompletion        = false;       # enabled through config, removing one compinit call.        
        zsh-abbr.enable         =  true;
        
        localVariables = {
          # _ZO_CMD_PREFIX="x";
            SHELL="${pkgs.zsh}/bin/zsh";
            PATH="$HOME/.nix-profile/bin:$PATH";
        };
      # .zshrc
        shellAliases = {

        };

      
# TODO: evaluation warning: `programs.zsh.initExtraFirst` is deprecated, use `programs.zsh.initContent` with `lib.mkBefore` instead.
#   Example: programs.zsh.initContent = lib.mkBefore "your content here";
# TODO: evaluation warning: `programs.zsh.initExtraBeforeCompInit` is deprecated, use `programs.zsh.initContent` with `lib.mkOrder 550` instead.
#   Example: programs.zsh.initContent = lib.mkOrder 550 "your content here";
# TODO: evaluation warning: `programs.zsh.initExtra` is deprecated, use `programs.zsh.initContent` instead.
#   Example: programs.zsh.initContent = "your content here";


      #! FOOTGUN: if you comment out a nix variable pointing to .filecontents, '#' only comments out the first line 
        
        initExtraFirst = ''
          zmodload zsh/zprof                                # zsh profiler

          #################PASSWORD ENTRY/CONFIRM DIALOGS GO ABOVE##############################

          # Powerlevel10k instant prompt.  anything requiring input/perf goes above, else below
            ${p10k_cfg}                                       

          # keybindings from various configs
            ${bindings_cfg}
          # end keybindings (we are bracketing these categories for collated zshrc debugging purposes)

          # setopts
            ${setopts_cfg}
          # end setopts

          # zstyle
            ${zstyle_cfg}                                     
          # end zstyle

          typeset -U path cdpath fpath manpath              # TODO: magic, no idea what it does anymore.
          autoload -U add-zsh-hook                          # TODO: Magic, no idea what it does anymore.

          zmodload zsh/terminfo                             # TODO: I think this is needed for `kitty` terminal

          WORDCHARS='*?[]~=&;!#$%^(){}<>';                  # Dont consider certain characters part of the word for nav
          
          
        '';
        
        initExtraBeforeCompInit = ''
          # zi
            # zi bootstrap
              ${zi_cfg}
            # end zi bootstrap

            # Zi plugins
              ${zi_plugins_cfg}
            # end zi plugins
          # end zi

          [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh      # TODO: marked for deletion, p10k deprecated

          # zicompinit                                        # zi cleanup
          autoload -Uz compinit
          compinit -C
        '';
        initExtra = ''
          # TODO: pull these into nix
          # Aliases
            alias "ll"="ls -l";
            alias "cp"="cp -i";                                     # Confirm before overwriting something
            alias "cd"="x";                                        # Empty oneletter for zoxide to not interfere with zi
            alias "exa"="eza --icons=always";                       # back compat for one of the tools
            alias "ls"="eza --icons=always --header --group-directories-first --hyperlink";
            alias "rustdevshell"="nix develop ~/nixos/dev-shells/rust#";
          # Atuin bindings and shell integration
        
          # Free up bindings for zellij
          ${zellij_keys_cfg}  


          # Necessary to run flakes, otherwise `#` gets expanded
            disable -p '#'  

          # Inshellisense
            # eval "$(is init zsh)"

          # homebrew
          export PATH="/opt/homebrew/bin:$PATH" # TODO: pull this out into nix's path definitions, matters for darwin
          
          # Justfile
          eval "$(${pkgs.just}/bin/just --completions zsh)"
        '';
    };
}


## Bash
  #? Shell integrations go here but main bash config is in the system one.
    # programs.bash.sessionVariables = {
    # };
    # programs.bash.shellAliases = {
    # };
  #? user bash aliases
    # programs.bash.shellAliases = {
    # };

  #? Extra commands that should be run when initializing an interactive shell.
    # programs.bash.initExtra = ''
    #     ${pkgs.inshellisense}/bin/inshellisense;
    # '';

  #? Extra commands that should be placed in {file}~/.bashrc.
  #?   Note that these commands will be run even in non-interactive shells.
    # programs.bash.bashrcExtra = ''
    # '';
  #? Extra commands that should be run when initializing a login shell.
  # programs.bash.profileExtra = ''
  # '';
  #? Extra commands that should be run when logging out of an interactive shell.
  # programs.bash.logoutExtra = ''
  # '';


  # programs.zoxide.enableBashIntegration = true;
  # programs.starship.enableBashIntegration = true;
  # programs.nix-index.enableBashIntegration = true;
  # programs.kitty.shellIntegration.enableBashIntegration = true;

  # programs.exa.enableBashIntegration = true;
  # programs.atuin.enableBashIntegration = true;


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

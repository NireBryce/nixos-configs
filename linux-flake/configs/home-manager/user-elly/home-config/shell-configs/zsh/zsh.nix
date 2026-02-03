# description = "zsh shell config";

# Notes:
# If you get `zsh side` errors, delete ~/.zcompdump and ~/.config/zsh/.zcompdump and run `zi update`
# installing multiple highlighters causes "zsh_zle-highlight-buffer-p:4: permission denied error
# in this case it was trapd00r/zsh-syntax-highlighting-filetypes which highlights more than filetypes turns out

# TO-DONE: evaluate oh-my-zsh, prezto
#          o-m-z is too all-encompassing still, but has best support
#          prezto not worth looking into imo because I want something stable
#          ironically this means going back to `zi` for now


# TODO:  MIGRATE OFF ZI
# TODO: evaluation warning: `programs.zsh.initExtraFirst` is deprecated, use `programs.zsh.initContent` with `lib.mkBefore` instead.
#   Example: programs.zsh.initContent = lib.mkBefore "your content here";
# evaluation warning: `programs.zsh.initExtraBeforeCompInit` is deprecated, use `programs.zsh.initContent` with `lib.mkOrder 550` instead.
#   Example: programs.zsh.initContent = lib.mkOrder 550 "your content here";
# evaluation warning: `programs.zsh.initExtra` is deprecated, use `programs.zsh.initContent` instead.
#   Example: programs.zsh.initContent = "your content here";

{ flake.modules.homeManager.common.shells.zsh =
{ pkgs, lib, ... }:
let zshPluginRequiresList = with pkgs; [
    diff-so-fancy
    # starship
    tree
    # ruby                            # zi depends on `gem`
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
in
{

    home.file."./.config/F-Sy-H".source = ./config/zsh-f-s-highlight-themes;
    home.packages = zshPluginRequiresList;
    
    programs.zsh = let               
        p10k_cfg        = lib.fileContents ./config/zsh-powerlevel10k/.p10k.zsh;
        bindings_cfg    = lib.fileContents ./config/initial-bindings.zsh;
        setopts_cfg     = lib.fileContents ./config/initial-setopts.zsh;
        zstyle_cfg      = lib.fileContents ./config/initial-zstyle.zsh;
        zellij_keys_cfg = lib.fileContents ./config/free-zellij-keys.zsh;
    in 
    {

        enable                  =  true;
        autocd                  = false;
        enableVteIntegration    =  true;
        autosuggestion.enable   =  true;
        enableCompletion        =  true;        #  may remove one compinit call if you disable here and enable in config      
        zsh-abbr.enable         =  true;
        
        
        history = {
            save = 10000;
            size = 10000;
            share = true;               # share history across sessions
        };

        plugins = [
            { 
                name = pkgs.nix-zsh-completions.pname;
                src = pkgs.nix-zsh-completions;
            }
            {
                name = pkgs.zsh-f-sy-h.pname;
                src = pkgs.zsh-f-sy-h;
            }
            {
                name = pkgs.zsh-nix-shell.pname;
                src = pkgs.zsh-nix-shell;
            }
            {
                name = pkgs.zsh-completions.pname;
                src = pkgs.zsh-completions;
            }
            {
                name = pkgs.zsh-autocomplete.pname;
                src = pkgs.zsh-autocomplete;
            }
            {
                name = pkgs.zsh-autosuggestions.pname;
                src = pkgs.zsh-autosuggestions;
            }
            # { 
            #     name = pkgs.zsh-powerlevel10k.pname; 
            #     src = pkgs.zsh-powerlevel10k.src;
            # }
            { 
                name = pkgs.zsh-system-clipboard.pname; 
                src = pkgs.zsh-system-clipboard;
            }
            {
                name = pkgs.zsh-you-should-use.pname; 
                src = pkgs.zsh-you-should-use;
            }
            {
                name = pkgs.zsh-fzf-tab.pname;
                src = pkgs.zsh-fzf-tab;
            }
        ];

        localVariables = {
        # _ZO_CMD_PREFIX="x";
            SHELL="${pkgs.zsh}/bin/zsh";
            PATH="$HOME/.nix-profile/bin:$PATH";
        };

        setOptions = [
          # From manjaro defaults:
            "correct"                               # Auto correct mistakes
            "nocaseglob"                            # Case insensitive globbing
            "rcexpandparam"                         # Array expension with parameters
            "nocheckjobs"                           # Don't warn about running processes when exiting
            "numericglobsort"                       # Sort filenames numerically when it makes sense
            "nobeep"                                # No beep
            "appendhistory"                         # Immediately append history instead of overwriting
            "histignorealldups"                     # If a new command is a duplicate, remove the older one
            "autocd"                                # if only directory path is entered, cd there.
            "inc_append_history"                    # save commands are added to the history immediately, otherwise only when shell exits.
            "histignorespace"                       # Don't save commands that start with space
            # "extendedglob"                          # Extended globbing. Allows using regular expressions with *
        
          # Prezto
            "COMPLETE_IN_WORD"                      # Complete from both ends of a word.
            "ALWAYS_TO_END"                         # Move cursor to the end of a completed word.
            "PATH_DIRS"                             # Perform path search even on command names with slashes.
            "AUTO_MENU"                             # Show completion menu on a successive tab press.
            "AUTO_LIST"                             # Automatically list choices on ambiguous completion.
            "AUTO_PARAM_SLASH"                      # If completed parameter is a directory, add a trailing slash.
            "EXTENDED_GLOB"                         # Needed for file modification glob modifiers with compinit.
            "extendedglob" #belt and suspenders

          # grabbed from zsh4humans
            "glob_dots"
            "globdots" #belt and suspenders            # no special treatment for file names with a leading dot
            # "no_auto_menu"                           # require an extra TAB press to open the completion menu
            "NO_MENU_COMPLETE"                         # Do not autoselect the first completion entry.
            "NO_FLOW_CONTROL"                          # Disable start/stop characters in shell editor.

        ];
    
        ## .zshrc
        #! FOOTGUN: if you comment out a nix variable pointing to .filecontents, '#' only comments out the first line 
        initExtraFirst = ''
            zmodload zsh/zprof                                # zsh profiler

            #################PASSWORD ENTRY/CONFIRM DIALOGS GO ABOVE##############################

            # Powerlevel10k instant prompt.  anything requiring input/perf goes above, else below
                                                      

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
            

            ### p10k cfg start
            ${p10k_cfg}
            ### p10k cfg end

            # zicompinit                                        # zi cleanup
            autoload -Uz compinit
            compinit -C
            '';
        initExtra = ''
            source <(${pkgs.cod}/bin/cod init $$ zsh)
            
            # TODO: pull these into nix
            # Aliases
                alias "ll"="ls -l";
                alias "cp"="cp -i";                                     # Confirm before overwriting something
                alias "exa"="eza --icons=always";                       # back compat for one of the tools
                alias "ls"="eza --icons=always --header --group-directories-first --hyperlink";
                alias "rustdevshell"="nix develop ~/nixos/dev-shells/rust#";
            
            # Free up bindings for zellij
            ${zellij_keys_cfg}  


            # Necessary to run flakes, otherwise `#` gets expanded
                disable -p '#'  

            # Inshellisense
                # eval "''$(is init zsh)"

            # homebrew
            export PATH="/opt/homebrew/bin:$PATH" # TODO: pull this out into nix's path definitions, matters for darwin
            
            # Justfile
            eval "''$(${pkgs.just}/bin/just --completions zsh)"
        '';
    };
};
}

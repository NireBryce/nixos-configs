{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            # zsh is handled through home-manager
            programs.zsh.enable = true;
            programs.zsh.enableCompletion = lib.mkForce false; # unless disabled, home-manager causes an extra compaudit
            environment.shells = with pkgs; [
                zsh
            ];
        };
        
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # Notes:
            # `zsh side` errors: delete ~/.zcompdump and ~/.config/zsh/.zcompdump
            # Multiple highlighters cause "zsh_zle-highlight-buffer-p:4: permission denied";
            # here it was trapd00r/zsh-syntax-highlighting-filetypes, which highlights more than filetypes

            # TO-DONE: evaluate oh-my-zsh, prezto -- o-m-z too all-encompassing but best support;
            #          prezto not worth it, want something stable

            # TO-DONE: migrate off zi. `5659567` dropped the last references to
            #          config/zi.zsh and config/zi-plugins.zsh; nothing has sourced
            #          zi since 2025-12-17, plugins are all programs.zsh.plugins now.
            #
            #          Seven plugins from the old zi list were never carried across and
            #          have been off since that date without being missed. Kept here
            #          because deleting zi-plugins.zsh deletes the only record:
            #            Tom-Power/fzf-tab-widgets        (fzf-tab itself -> zsh-fzf-tab)
            #            akash329d/zsh-alias-finder
            #            jgogstad/zsh-mask
            #            ael-code/zsh-colored-man-pages
            #            chrissicool/zsh-256color
            #            zpm-zsh/colorize                 (colorizes gcc/grep/etc)
            #            RobSis/zsh-completion-generator
            #
            #          The file's z-a-* entries were zi annexes, meaningless without zi;
            #          its `unset python` marked "MAGIC: idk why this is here" is possibly
            #          related to the equally unexplained PYTHON = "PYTHON" in shell-env.nix.

            # fast syntax highlighting theems
            home.file."./.config/F-Sy-H".source = ./config/zsh-f-s-highlight-themes;

            # plugin dependencies
            home.packages = with pkgs; [
                diff-so-fancy
                # starship                        # enabled via programs.starship, see appearance-cli/starship.nix
                tree
                # ruby                            # zi depends on `gem`
                nix-zsh-completions
                zsh-f-sy-h
                zsh-fzf-tab
                zsh-nix-shell
                zsh-completions
                zsh-autocomplete
                zsh-autosuggestions
                zsh-system-clipboard
                zsh-you-should-use
            ];

            programs.zsh =
            let
                bindings_cfg = lib.fileContents ./config/initial-bindings.zsh;
                setopts_cfg = lib.fileContents ./config/initial-setopts.zsh;
                zstyle_cfg = lib.fileContents ./config/initial-zstyle.zsh;
                zellij_keys_cfg = lib.fileContents ./config/free-zellij-keys.zsh;
            in 
            {
                zsh-abbr.abbreviations = {
                    "abbr remove" = "abbr erase";
                    "abbr rm" = "abbr erase";
                    "cs-zsh-bindings" = "bindkey";
                    "cs-zsh-highlighting" = "fast-theme sv-orple";
                    "wh" = "wormhole";
                    "whence" = "type -a";
                    "zsh-keymap" = "bindkey";
                };
                enable = true;
                autocd = false;
                enableVteIntegration = true;
                autosuggestion.enable = true;
                enableCompletion = true; # may remove one compinit call if you disable here and enable in config
                zsh-abbr.enable = true;

                history = {
                    save = 10000;
                    size = 10000;
                    share = true; # share history across sessions
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
                    SHELL = "${pkgs.zsh}/bin/zsh";
                    PATH = "$HOME/.nix-profile/bin:$PATH";
                };

                setOptions = [
                    # From manjaro defaults:
                    "correct" # Auto correct mistakes
                    "nocaseglob" # Case insensitive globbing
                    "rcexpandparam" # Array expension with parameters
                    "nocheckjobs" # Don't warn about running processes when exiting
                    "numericglobsort" # Sort filenames numerically when it makes sense
                    "nobeep" # No beep
                    "appendhistory" # Immediately append history instead of overwriting
                    "histignorealldups" # If a new command is a duplicate, remove the older one
                    "autocd" # if only directory path is entered, cd there.
                    "inc_append_history" # save commands are added to the history immediately, otherwise only when shell exits.
                    "histignorespace" # Don't save commands that start with space
                    # "extendedglob"                          # Extended globbing. Allows using regular expressions with *

                    # Prezto
                    "COMPLETE_IN_WORD" # Complete from both ends of a word.
                    "ALWAYS_TO_END" # Move cursor to the end of a completed word.
                    "PATH_DIRS" # Perform path search even on command names with slashes.
                    "AUTO_MENU" # Show completion menu on a successive tab press.
                    "AUTO_LIST" # Automatically list choices on ambiguous completion.
                    "AUTO_PARAM_SLASH" # If completed parameter is a directory, add a trailing slash.
                    "EXTENDED_GLOB" # Needed for file modification glob modifiers with compinit.
                    "extendedglob" # belt and suspenders

                    # grabbed from zsh4humans
                    "glob_dots"
                    "globdots" # belt and suspenders            # no special treatment for file names with a leading dot
                    # "no_auto_menu"                           # require an extra TAB press to open the completion menu
                    "NO_MENU_COMPLETE" # Do not autoselect the first completion entry.
                    "NO_FLOW_CONTROL" # Disable start/stop characters in shell editor.

                ];

                ## .zshrc
                #! FOOTGUN: if you comment out a nix variable pointing to .filecontents, '#' only comments out the first line
                initContent = lib.mkMerge [
                    (lib.mkBefore ''
                    zmodload zsh/zprof                                # zsh profiler

                    # nixpkgs' programs.ssh module exports SSH_ASKPASS globally
                    # whenever services.xserver.enable is true (kde-desktop,
                    # so durandal and cube), with no way to scope it to
                    # sessions that have a display. Over plain SSH anything
                    # using it crashes instead of falling back to a terminal
                    # prompt -- ksshaskpass needs a Qt/X11 platform that isn't
                    # there. Same fix as bash.nix's initExtra, which has the
                    # 2026-08-26 incident. Harmless no-op on a host that never
                    # had it set, or a real graphical session.
                    if [[ -z "''${DISPLAY:-}''${WAYLAND_DISPLAY:-}" ]]; then
                        unset SSH_ASKPASS
                    fi

                    #################PASSWORD ENTRY/CONFIRM DIALOGS GO ABOVE##############################

                    # anything requiring input/perf goes above, else below
                                                            
                    # keybindings from various configs
                        ${bindings_cfg}
                    # end keybindings (we are bracketing these categories for collated zshrc debugging purposes)

                    # setopts
                        ${setopts_cfg}
                    # end setopts

                    # zstyle
                        ${zstyle_cfg}                                     
                    # end zstyle

                    typeset -U path cdpath fpath manpath              # -U keeps these arrays unique, i.e. dedupes $PATH and friends
                    autoload -U add-zsh-hook                          # makes add-zsh-hook callable. Nothing here registers a hook,
                                                                      # so this is currently unused

                    zmodload zsh/terminfo                             # provides the $terminfo array, which
                                                                      # config/initial-bindings.zsh reads as terminfo[khome] /
                                                                      # terminfo[kend] to bind Home and End. Not kitty-specific,
                                                                      # despite the old note here.

                    WORDCHARS='*?[]~=&;!#$%^(){}<>';                  # Dont consider certain characters part of the word for nav
                '')

                    (lib.mkOrder 550 ''
                    # zicompinit                                        # zi cleanup
                    autoload -Uz compinit
                    compinit -C
                '')
                    # Deliberately no aliases in this block: `#` inside a ''
                    # string is shell text, not a Nix comment, so the reasoning
                    # lives above the string rather than being emitted into
                    # ~/.zshrc.
                    #
                    # home.shellAliases is emitted *after* initContent and later
                    # definitions win, so an alias written here that also exists
                    # there is dead. Four were: ll, cp and exa duplicated
                    # shell-env.nix exactly, and `ls` lost to the `ls = eza`
                    # that programs.eza generates. That one loses nothing --
                    # aliases expand recursively, so `ls` -> `eza` -> the full
                    # flagged command from programs.eza.extraOptions -- and
                    # re-adding `ls` would *break* that chain, dropping
                    # --color, --git and -1. Change the flags in
                    # nirePackages/shell-apps/navigation/eza.nix instead.
                    #
                    # `rustdevshell` did survive, nothing else defining it, but
                    # was stale twice over: the checkout is nixos-configs, and
                    # that dev-shell is parked in ignore/dev-shells/rust/,
                    # wired into nothing.
                    #
                    # Add aliases to home.shellAliases in shell-env.nix.
                    #
                    # cod is broken on darwin (nixpkgs: meta.broken =
                    # stdenv.hostPlatform.isDarwin), so pkgs.cod can't be
                    # evaluated there -- lib.optionalString below keeps that
                    # interpolation unforced when the condition is false, same
                    # reasoning as the lib.mkIf guards elsewhere in this tree
                    # (see elly-home-manager.nix). A real Nix comment up here,
                    # not inside the '' string below, per the `#` note above.
                    #
                    # cod's source line must come before carapace's: zsh's
                    # compdef, like bash's complete -F, is last-registration-
                    # wins per command, and cod-completions.nix's ignore-list
                    # only stops cod from *re*-claiming a command carapace
                    # covers, not its first registration this session -- see
                    # that file and bash.nix's identical ordering note.
                    #
                    # carapace itself builds on darwin (unlike cod), so its own
                    # line needs no guard. And zsh's completion system (compsys)
                    # natively supports paired descriptions, so carapace's zsh
                    # output shows them for free -- no equivalent of blesh.nix's
                    # carapace-desc advice hook is needed here.
                    ''
                    ${lib.optionalString (!pkgs.stdenv.isDarwin) "source <(${pkgs.cod}/bin/cod init $$ zsh)"}
                    source <(${pkgs.carapace}/bin/carapace _carapace zsh)

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
                ''
                ];
            };
        };
}

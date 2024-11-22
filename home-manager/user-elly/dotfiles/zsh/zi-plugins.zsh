#TODO: move off zi
        # completions from --help
        # source "${HOME}/.zi/plugins/RobSis---zsh-completion-generator/zsh-completion-generator.plugin.zsh" 

    # Install packages
      # fzf plugins
        zi load Aloxaf/fzf-tab                # todo: nix config?
        zi load Tom-Power/fzf-tab-widgets
        
      #???
        zi light dim-an/cod


        
      # zoxide plugin
        # zi has'zoxide' wait lucid for z-shell/zsh-zoxide   # do we actually need this? the only reason we need to use this is because zi binds over zoxide's default zi binding, but we already added that to the nix thing

    # Plugins
      # Aliases
        # zi light akash329d/zsh-alias-finder 
        # zi light olets/zsh-abbr                                                 # abbr - Alias but more annoying for you, less annoying for everyone around you 

      # annexes and metaplugins
        zi light-mode for z-shell/z-a-meta-plugins @zsh-users+fast              # https://github.com/z-shell/zsh-fancy-completions
        zi light z-shell/z-a-bin-gem-node                                       # uhhhhh https://wiki.zshell.dev/ecosystem/annexes/bin-gem-node but it's not that important
        zi light z-shell/z-a-patch-dl                               # todo: only need if we care about zi

      # Autosuggest -- use right-arrow to complete
        zi light zsh-users/zsh-autosuggestions

      # clipboard
        zi light kutsan/zsh-system-clipboard                                    # synchronize tmux clipboard buffers if ZSH_SYSTEM_CLIPBOARD_TMUX_SUPPORT='true'
                                                                                # Also enables clipboard use in the zsh vi-mode line editor
      # diff
        zi light https://github.com/z-shell/zsh-diff-so-fancy

      # History plugins
        zi light jgogstad/zsh-mask # todo: better ways?
        # zi load z-shell/H-S-MW # history-search-multi_word
        # zi load zsh-users/zsh-history-substring-search
        # zi light tymm/zsh-directory-history

      # man / help
        # zi light mattmc3/zman                                                   # https://github.com/mattmc3/zman
        zi light ael-code/zsh-colored-man-pages # todo: just import this
        zi light z-shell/z-a-man    # todo: don't actually need, prefer non-plugin utilities                                            # https://github.com/z-shell/z-a-man
      
      # ssh  
        # zi light gko/ssh-connect

      # Shell plugins
          # zi light https://github.com/gmatheu/shell-plugins                     # WARN: flaky

      # syntax highlighting
        # zi light z-shell/F-Sy-H

        # # a different highlighter plugin, misleadingly named but cool colors 
          # zi light trapd00r/zsh-syntax-highlighting-filetypes                     # https://github.com/trapd00r/zsh-syntax-highlighting-filetypes
          # it gives "zsh_zle-highlight-buffer-p:4: permission denied error
      # Themes and colors
        zi ice depth=1; zi light romkatv/powerlevel10k                          # TODO: just find a pretty prompt transient prompt is probably less useful anyway since you mix shells

        zi light chrissicool/zsh-256color # figure out how to do via nix
        zi light zpm-zsh/colorize        # todo: this colorizes gcc, grep, etc.  figure out how to do that via nix                                        # color common commands
      
      # MAGIC: idk why this is here, but it's needed to make zsh not print python=python every login
        # you might be able to remove this
        unset python
        
      # Completions
        zi load RobSis/zsh-completion-generator # todo: do I even need this
        zi light 3v1n0/zsh-bash-completions-fallback                            # https://github.com/3v1n0/zsh-bash-completions-fallback
        zi light clarketm/zsh-completions                                       # additional completions https://github.com/clarketm/zsh-completions
        zi light MenkeTechnologies/zsh-more-completions
        zi light syohex/zsh-misc-completions
        zi light MenkeTechnologies/zsh-cargo-completions



# zi light alexiszamanidis/zsh-git-fzf                                  # https://github.com/alexiszamanidis/zsh-git-fzf

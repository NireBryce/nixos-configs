# ZI PACKAGE/PLUGIN MANAGEMENT

    # completions from --help
    source "${HOME}/.zi/plugins/RobSis---zsh-completion-generator/zsh-completion-generator.plugin.zsh" 

# Install packages
  # fzf plugins
    zi load Aloxaf/fzf-tab
    zi light alexiszamanidis/zsh-git-fzf                                  # https://github.com/alexiszamanidis/zsh-git-fzf
  # zoxide plugin
    zi has'zoxide' wait lucid for z-shell/zsh-zoxide

# Plugins
  # Aliases
    zi light akash329d/zsh-alias-finder 
    zi light olets/zsh-abbr                                                 # abbr - Alias but more annoying for you, less annoying for everyone around you 

  # annexes and metaplugins
    zi light-mode for z-shell/z-a-meta-plugins @zsh-users+fast              # https://github.com/z-shell/zsh-fancy-completions
    zi light z-shell/z-a-bin-gem-node                                       # uhhhhh https://wiki.zshell.dev/ecosystem/annexes/bin-gem-node but it's not that important
    zi light z-shell/z-a-patch-dl

  # Autosuggest -- use right-arrow to complete
    zi light zsh-users/zsh-autosuggestions

  # cheatsheets
    zi light 0b10/cheatsheet

  # clipboard
    zi light kutsan/zsh-system-clipboard                                    # synchronize tmux clipboard buffers if ZSH_SYSTEM_CLIPBOARD_TMUX_SUPPORT='true'
                                                                            # Also enables clipboard use in the zsh vi-mode line editor
  # diff
    zi light https://github.com/z-shell/zsh-diff-so-fancy

  # History plugins
    zi light jgogstad/passwordless-history
    # zi load z-shell/H-S-MW # history-search-multi_word
    # zi load zsh-users/zsh-history-substring-search
    # zi light tymm/zsh-directory-history

  # man / help
    zi light mattmc3/zman                                                   # https://github.com/mattmc3/zman
    zi light ael-code/zsh-colored-man-pages
    zi light z-shell/z-a-man                                                # https://github.com/z-shell/z-a-man
  
  # ssh  
    zi light gko/ssh-connect

  # Shell plugins
      # zi light https://github.com/gmatheu/shell-plugins                     # WARN: flaky

  # syntax highlighting
    zi light z-shell/F-Sy-H
    # # a different highlighter plugin, misleadingly named but cool colors 
      # zi light trapd00r/zsh-syntax-highlighting-filetypes                     # https://github.com/trapd00r/zsh-syntax-highlighting-filetypes
      # it gives "zsh_zle-highlight-buffer-p:4: permission denied error
  # Themes and colors
    zi ice depth=1; zi light romkatv/powerlevel10k                          # Powerlevel 10k - main theme
    zi light chrissicool/zsh-256color
    zi light zpm-zsh/colorize                                               # color common commands
  
  # MAGIC: idk why this is here, but it's needed to make zsh not print python=python every login
    # you might be able to remove this
    unset python

  # Completions
    zi load RobSis/zsh-completion-generator
    zi light 3v1n0/zsh-bash-completions-fallback                            # https://github.com/3v1n0/zsh-bash-completions-fallback
    zi light clarketm/zsh-completions                                       # https://github.com/clarketm/zsh-completions



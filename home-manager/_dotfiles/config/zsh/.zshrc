# Enable Powerlevel10k instant prompt. 
  # Should stay close to the top of ~/.zshrc.
  # Initialization code that may require console input (password prompts, [y/n]
  # confirmations, etc.) must go above this block; everything else may go below.
    if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
      source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
    fi
# other head-of-file stuff
  #MAGIC: no idea but zsh wants it
  typeset -U path cdpath fpath manpath

  #MAGIC: needed for nix
  for profile in ${(z)NIX_PROFILES}; do
    fpath+=($profile/share/zsh/site-functions $profile/share/zsh/$ZSH_VERSION/functions $profile/share/zsh/vendor-completions)
  done

# Zi
  # zi install
    if [[ ! -d "$HOME/.zi" ]]; then
      sh -c "$(curl -fsSL get.zshell.dev)" -- -a loader
    fi

  # zi bootstrap
    if [[ -r "${XDG_CONFIG_HOME:-${HOME}/.config}/zi/init.zsh" ]]; then
      source "${XDG_CONFIG_HOME:-${HOME}/.config}/zi/init.zsh" && zzinit
    fi

# initial defaults from other sources (zsh4humans, prezto, manjaro)   
    source "${HOME}/.config/zsh/initial-bindings.zsh"
    source "${HOME}/.config/zsh/initial-setopts.zsh"
    source "${HOME}/.config/zsh/initial-zstyle.zsh"

# things at the bottom but before plugins
  # MAGIC: these are from what the above sources were from, and idk what they're for
    autoload -U add-zsh-hook
    # fpath=($HOME/.nix-profile/share/zsh/site-functions $fpath)
    # add-zsh-hook precmd mzc_termsupport_precmd
    # add-zsh-hook preexec mzc_termsupport_preexec
    zmodload zsh/terminfo
    WORDCHARS='*?[]~=&;!#$%^(){}<>';       # Don't consider certain characters part of the word

# Plugins
  
  # zi plugins
    source $HOME/.config/zsh/zi-plugins.zsh
  
  # Completions not-otherwise-defined
    source $HOME/.zi/plugins/RobSis---zsh-completion-generator/zsh-completion-generator.plugin.zsh
    
    # pip completions
      # eval "$(python -m pip completion --zsh)"                              # Currently broken, see https://github.com/pypa/pip/issues/12166

    # zellij completions
      # eval "$(zellij setup --generate-completion zsh)"
    

# compinit and cleanup
    zicompinit                                                              # <- https://wiki.zshell.dev/docs/guides/commands
    autoload -Uz compinit
    compinit

# integrations after compinit:
  # Atuin
      export ATUIN_NOBIND="true"
      eval "$(atuin init zsh --disable-up-arrow)"
      bindkey '^r' _atuin_search_widget

# Theming
  # set f-sy-h theme 
    # fast-theme z-shell
  # p10k prompt theme
    # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
    [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# User bindings
  # free up keybindings for copy/paste in zellij after other keybindings are set
    bindkey -r "^V"
    bindkey -r "^v"
    bindkey -r "^[v"
    bindkey -r "^[V"
    bindkey -r "^[c"
    bindkey -r "^[C"
  
# disable # parsing so you can do flakes
  # https://stackoverflow.com/questions/12303805/oh-my-zsh-hash-pound-symbol-bad-pattern-or-match-not-found/57380936#57380936
  # this fixes nix-flakes
  disable -p '#'

# enable hash (#) character for line-comments by turning off extended globbing
    # unsetopt extended_glob
    # setopt interactive_comments
  
# Aliases: 
  # home.shellAliases in nix isn't sticking for some reason.  
  alias ll="ls -l";
  alias cp="cp -i";                              # Confirm before overwriting something
  alias cd="x";                                  # Empty oneletter for zoxide to not interfere with zi
  alias exa="eza --icons=always";
  alias ls="eza --icons=always --header --group-directories-first";

# Needed for firstrun	
  # source ${HOME}/.config/zsh/abbr-set-global.zsh



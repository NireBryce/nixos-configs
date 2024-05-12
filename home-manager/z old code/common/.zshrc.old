  # Zellij autostart
    # eval "$(zellij setup --generate-auto-start zsh)"

  # make sure loacle is set
    export LC_CTYPE=en_US.UTF-8 

  # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
  # Initialization code that may require console input (password prompts, [y/n]
  # confirmations, etc.) must go above this block; everything else may go below.
    if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
      source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
    fi


typeset -U path cdpath fpath manpath

for profile in ${(z)NIX_PROFILES}; do
  fpath+=($profile/share/zsh/site-functions $profile/share/zsh/$ZSH_VERSION/functions $profile/share/zsh/vendor-completions)
done


# make this a symlink so it's portable across devices
  #HELPDIR="/nix/store/9r9lh146ysmc43v11nbzy029lzv2b4wz-zsh-5.9/share/zsh/$ZSH_VERSION/help"


# make this a symlink so it's portable across devices
  #eval $(/nix/store/zx8aqgdy735qzk81glfwil6mbi6ddqb1-coreutils-9.4/bin/dircolors -b ~/.dir_colors)

#source  ~/.nix-profile/etc/profile.d/nix.sh

# zi install
  if [[ ! -d "$HOME/.zi" ]]; then
      sh -c "$(curl -fsSL get.zshell.dev)" -- -a loader
  fi


# Zi bootstrap
  if [[ -r "${XDG_CONFIG_HOME:-${HOME}/.config}/zi/init.zsh" ]]; then
    source "${XDG_CONFIG_HOME:-${HOME}/.config}/zi/init.zsh" && zzinit
  fi


# Oh-My-Zsh/Prezto calls compinit during initialization,
# calling it twice causes slight start up slowdown
# as all $fpath entries will be traversed again.
# autoload -U compinit && compinit

###############################################################################################################################
# STOLEN FROM MANJARO DEFAULT CONFIG
############################################

  
  # zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}'
    
  # Options section
    setopt correct                                                  # Auto correct mistakes
    setopt nocaseglob                                               # Case insensitive globbing
    setopt rcexpandparam                                            # Array expension with parameters
    setopt nocheckjobs                                              # Don't warn about running processes when exiting
    setopt numericglobsort                                          # Sort filenames numerically when it makes sense
    setopt nobeep                                                   # No beep
    setopt appendhistory                                            # Immediately append history instead of overwriting
    setopt histignorealldups                                        # If a new command is a duplicate, remove the older one
    setopt autocd                                                   # if only directory path is entered, cd there.
    setopt inc_append_history                                       # save commands are added to the history immediately, otherwise only when shell exits.
    setopt histignorespace                                          # Don't save commands that start with space
    # disabled after the fact:
      # setopt extendedglob                                         # Extended globbing. Allows using regular expressions with *
    zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'   # Case insensitive tab completion
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"         # Colored completion (different colors for dirs/files/etc)
    zstyle ':completion:*' rehash true                              # automatically find new executables in path 
  # Speed up completions
    zstyle ':completion:*' accept-exact '*(N)'
    zstyle ':completion:*' use-cache on
    zstyle ':completion:*' cache-path ~/.zsh/cache
  # History
    HISTFILE=~/.zhistory
    HISTSIZE=10000
    SAVEHIST=10000
    WORDCHARS=${WORDCHARS//\/[&.;]}                                 # Don't consider certain characters part of the word


  # Keybindings section
    bindkey -e
    bindkey '^[[7~' beginning-of-line                               # Home key
    bindkey '^[[H' beginning-of-line                                # Home key
    if [[ "${terminfo[khome]}" != "" ]]; then
      bindkey "${terminfo[khome]}" beginning-of-line                # [Home] - Go to beginning of line
    fi
    bindkey '^[[8~' end-of-line                                     # End key
    bindkey '^[[F' end-of-line                                      # End key
    if [[ "${terminfo[kend]}" != "" ]]; then
      bindkey "${terminfo[kend]}" end-of-line                       # [End] - Go to end of line
    fi
    bindkey '^[[2~' overwrite-mode                                  # Insert key
    bindkey '^[[3~' delete-char                                     # Delete key
    bindkey '^[[C'  forward-char                                    # Right key
    bindkey '^[[D'  backward-char                                   # Left key
    bindkey '^[[5~' history-beginning-search-backward               # Page up key
    bindkey '^[[6~' history-beginning-search-forward                # Page down key

  # Navigate words with ctrl+arrow keys
    bindkey '^[Oc' forward-word                                     #
    bindkey '^[Od' backward-word                                    #
    bindkey '^[[1;5D' backward-word                                 #
    bindkey '^[[1;5C' forward-word                                  #
    bindkey '^H' backward-kill-word                                 # delete previous word with ctrl+backspace
    bindkey '^[[Z' undo                                             # Shift+tab undo last action

  # Alias section
    alias cp="cp -i"                                                # Confirm before overwriting something


  # Offer to install missing package if command is not found
    if [[ -r /usr/share/zsh/functions/command-not-found.zsh ]]; then
        source /usr/share/zsh/functions/command-not-found.zsh
        export PKGFILE_PROMPT_INSTALL_MISSING=1
    fi

  # Prezto
    setopt COMPLETE_IN_WORD                                         # Complete from both ends of a word.
    setopt ALWAYS_TO_END                                            # Move cursor to the end of a completed word.
    setopt PATH_DIRS                                                # Perform path search even on command names with slashes.
    setopt AUTO_MENU                                                # Show completion menu on a successive tab press.
    setopt AUTO_LIST                                                # Automatically list choices on ambiguous completion.
    setopt AUTO_PARAM_SLASH                                         # If completed parameter is a directory, add a trailing slash.
    setopt EXTENDED_GLOB                                            # Needed for file modification glob modifiers with compinit.
    setopt extendedglob #belt and suspenders
    
  # grabbed from zsh4humans
    setopt glob_dots
    setopt globdots #belt and suspenders                                                # no special treatment for file names with a leading dot
    # user disabled:
      # setopt no_auto_menu                                         # require an extra TAB press to open the completion menu
    
    unsetopt MENU_COMPLETE                                          # Do not autoselect the first completion entry.
    unsetopt FLOW_CONTROL                                           # Disable start/stop characters in shell editor.

  # Group matches and describe.
    zstyle ':completion:*:*:*:*:*' menu select
    zstyle ':completion:*:matches' group 'yes'
    zstyle ':completion:*:options' description 'yes'
    zstyle ':completion:*:options' auto-description '%d'
    zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
    zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
    zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
    zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
    zstyle ':completion:*' format ' %F{yellow}-- %d --%f'
    zstyle ':completion:*' group-name ''
    zstyle ':completion:*' verbose yes

  # Don't complete unavailable commands.
    zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'
   
  # Array completion element sorting.
    zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters
   
  # Directories
    zstyle ':completion:*:*:cd:*' tag-order local-directories directory-stack path-directories
    zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
    zstyle ':completion:*:-tilde-:*' group-order 'named-directories' 'path-directories' 'users' 'expand'
    zstyle ':completion:*' squeeze-slashes true

  # History
    zstyle ':completion:*:history-words' stop yes
    zstyle ':completion:*:history-words' remove-all-dups yes
    zstyle ':completion:*:history-words' list false
    zstyle ':completion:*:history-words' menu yes
   
  # Environment Variables
    zstyle ':completion::*:(-command-|export):*' fake-parameters ${${${_comps[(I)-value-*]#*,}%%,*}:#-*-}
   
  # Populate hostname completion. But allow ignoring custom entries from static
  # */etc/hosts* which might be uninteresting.
    zstyle -a ':prezto:module:completion:*:hosts' etc-host-ignores '_etc_host_ignores'
    
    zstyle -e ':completion:*:hosts' hosts 'reply=(
      ${=${=${=${${(f)"$(cat {/etc/ssh/ssh_,~/.ssh/}known_hosts(|2)(N) 2> /dev/null)"}%%[#| ]*}//\]:[0-9]*/ }//,/ }//\[/ }
      ${=${(f)"$(cat /etc/hosts(|)(N) <<(ypcat hosts 2> /dev/null))"}%%(\#${_etc_host_ignores:+|${(j:|:)~_etc_host_ignores}})*}
      ${=${${${${(@M)${(f)"$(cat ~/.ssh/config 2> /dev/null)"}:#Host *}#Host }:#*\**}:#*\?*}}
    )'
   
   # Don't complete uninteresting users...
    zstyle ':completion:*:*:*:users' ignored-patterns \
      adm amanda apache avahi beaglidx bin cacti canna clamav daemon \
      dbus distcache dovecot fax ftp games gdm gkrellmd gopher \
      hacluster haldaemon halt hsqldb ident junkbust ldap lp mail \
      mailman mailnull mldonkey mysql nagios \
      named netdump news nfsnobody nobody nscd ntp nut nx openvpn \
      operator pcap postfix postgres privoxy pulse pvm quagga radvd \
      rpc rpcuser rpm shutdown squid sshd sync uucp vcsa xfs '_*'
   
   # ... unless we really want to.
    zstyle '*' single-ignored show
   
   # Ignore multiple entries.
    zstyle ':completion:*:(rm|kill|diff):*' ignore-line other
    zstyle ':completion:*:rm:*' file-patterns '*:all-files'
   
   # Kill
    zstyle ':completion:*:*:*:*:processes' command 'ps -u $LOGNAME -o pid,user,command -w'
    zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;36=0=01'
    zstyle ':completion:*:*:kill:*' menu yes select
    zstyle ':completion:*:*:kill:*' force-list always
    zstyle ':completion:*:*:kill:*' insert-ids single
   
   # Man
    zstyle ':completion:*:manuals' separate-sections true
    zstyle ':completion:*:manuals.(^1*)' insert-sections true
   
   # Media Players
    zstyle ':completion:*:*:mpg123:*' file-patterns '*.(mp3|MP3):mp3\ files *(-/):directories'
    zstyle ':completion:*:*:mpg321:*' file-patterns '*.(mp3|MP3):mp3\ files *(-/):directories'
    zstyle ':completion:*:*:ogg123:*' file-patterns '*.(ogg|OGG|flac):ogg\ files *(-/):directories'
    zstyle ':completion:*:*:mocp:*' file-patterns '*.(wav|WAV|mp3|MP3|ogg|OGG|flac):ogg\ files *(-/):directories'
   
  # Mutt
   if [[ -s "$HOME/.mutt/aliases" ]]; then
     zstyle ':completion:*:*:mutt:*' menu yes select
     zstyle ':completion:*:mutt:*' users ${${${(f)"$(<"$HOME/.mutt/aliases")"}#alias[[:space:]]}%%[[:space:]]*}
   fi
   
  # SSH/SCP/RSYNC
    zstyle ':completion:*:(ssh|scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
    zstyle ':completion:*:(scp|rsync):*' group-order users files all-files hosts-domain hosts-host hosts-ipaddr
    zstyle ':completion:*:ssh:*' group-order users hosts-domain hosts-host users hosts-ipaddr
    zstyle ':completion:*:(ssh|scp|rsync):*:hosts-host' ignored-patterns '*(.|:)*' loopback ip6-loopback localhost ip6-localhost broadcasthost
    zstyle ':completion:*:(ssh|scp|rsync):*:hosts-domain' ignored-patterns '<->.<->.<->.<->' '^[-[:alnum:]]##(.[-[:alnum:]]##)##' '*@*'
    zstyle ':completion:*:(ssh|scp|rsync):*:hosts-ipaddr' ignored-patterns '^(<->.<->.<->.<->|(|::)([[:xdigit:].]##:(#c,2))##(|%*))' '127.0.0.<->' '255.255.255.255' '::1' 'fe80::*'

    autoload -U add-zsh-hook
  # add-zsh-hook precmd mzc_termsupport_precmd
  # add-zsh-hook preexec mzc_termsupport_preexec

  ## Plugins section: Enable fish style features
    # bind UP and DOWN arrow keys to history substring search
    # bindkey "$terminfo[kcuu1]" history-substring-search-up
    # bindkey "$terminfo[kcud1]" history-substring-search-down
    # bindkey '^[[A' history-substring-search-up
    # bindkey '^[[B' history-substring-search-down
    zmodload zsh/terminfo

  # Bindkeys from I think zsh for humans
    'bindkey' '-d'
    'bindkey' '-e'

    'bindkey' '-s' '^[OM'    '^M'
    'bindkey' '-s' '^[Ok'    '+'
    'bindkey' '-s' '^[Om'    '-'
    'bindkey' '-s' '^[Oj'    '*'
    'bindkey' '-s' '^[Oo'    '/'
    'bindkey' '-s' '^[OX'    '='
    'bindkey' '-s' '^[OH'    '^[[H'
    'bindkey' '-s' '^[OF'    '^[[F'
    'bindkey' '-s' '^[OA'    '^[[A'
    'bindkey' '-s' '^[OB'    '^[[B'
    'bindkey' '-s' '^[OD'    '^[[D'
    'bindkey' '-s' '^[OC'    '^[[C'
    'bindkey' '-s' '^[[1~'   '^[[H'
    'bindkey' '-s' '^[[4~'   '^[[F'
    'bindkey' '-s' '^[Od'    '^[[1;5D'
    'bindkey' '-s' '^[Oc'    '^[[1;5C'
    'bindkey' '-s' '^[^[[D'  '^[[1;3D'
    'bindkey' '-s' '^[^[[C'  '^[[1;3C'
    'bindkey' '-s' '^[[7~'   '^[[H'
    'bindkey' '-s' '^[[8~'   '^[[F'
    'bindkey' '-s' '^[[3\^'  '^[[3;5~'
    'bindkey' '-s' '^[^[[3~' '^[[3;3~'
    'bindkey' '-s' '^[[1;9D' '^[[1;3D'
    'bindkey' '-s' '^[[1;9C' '^[[1;3C'

    'bindkey' '^[[H'    'beginning-of-line'
    'bindkey' '^[[F'    'end-of-line'
    'bindkey' '^[[3~'   'delete-char'
    'bindkey' '^[[3;5~' 'kill-word'
    'bindkey' '^[[3;3~' 'kill-word'
    'bindkey' '^[k'     'backward-kill-line'
    'bindkey' '^[K'     'backward-kill-line'
    'bindkey' '^[j'     'kill-buffer'
    'bindkey' '^[J'     'kill-buffer'
    'bindkey' '^[/'     'redo'                          # Alt + /
    'bindkey' '^[[1;3D' 'backward-word'
    'bindkey' '^[[1;5D' 'backward-word'
    'bindkey' '^[[1;3C' 'forward-word'
    'bindkey' '^[[1;5C' 'forward-word'
############################################
# END FRONTMATTER
###############################################################################################################################

###############################################################################################################################
# EXPORTS
############################################
    
  # nix
    export NIXPKGS_ALLOW_UNFREE=1
    # export PATH="$PATH:/nix/var/nix/profiles/default/bin"
    fpath=($HOME/.nix-profile/share/zsh/site-functions $fpath)
    # if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; 
    #   then
    #   . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    # fi
        
  # $PATH -- these need to go above the plugins and execs
    # Cargo
      export PATH="$HOME/.cargo/bin:$PATH"
    # misc/admin
      export PATH="/usr/local:$PATH"
      export PATH="/usr/bin:$PATH"
      export PATH="$HOME/.local:$PATH"
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/.zi/bin:$PATH"
      export PATH="$HOME/.config/zi/bin:$PATH"
    # emacs
      export PATH="$HOME/.config/emacs/bin:$PATH"
  # application and utility exports
    # Rust SCCACHE (keeps cache of compilation artefacts so it's not constantly building things it already has
      #export RUSTC_WRAPPER="sccache cargo build"  
    # better python pdb breakpoints
      export PYTHONBREAKPOINT=ipdb.set_trace
  # shell and OS
    # Editors and pagers
      export EDITOR=micro # default to micro, if we need a different reader, we can set the editor flag ourselves
      export MICRO_TRUECOLOR=1 
      export COLORTERM=truecolor
      export PAGER="less -R"
      export MANPAGER="bat --language man"

  # emacs
  # completions
    # fpath=(
    #   $HOME/.config/zsh.d/completions 
    #   $fpath
    # )
  
############################################
# END EXPORTS
###############################################################################################################################

###############################################################################################################################
# ZI PACK/PLUG MANAGEMENT
############################################

  # Install packages
    # install FZF
      # zi pack"binary" for fzf

      # fzf plugins
        zi load Aloxaf/fzf-tab
        zi light alexiszamanidis/zsh-git-fzf                                  # https://github.com/alexiszamanidis/zsh-git-fzf

    # install zoxide
      #make it not interfere with zi
      _ZO_CMD_PREFIX="f" 
      # zi ice as'null' from"gh-r" sbin
      # zi light ajeetdsouza/zoxide                                             
      # Zoxide plugin
        zi has'zoxide' wait lucid for \
        z-shell/zsh-zoxide
        
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
      zi light trapd00r/zsh-syntax-highlighting-filetypes                     # https://github.com/trapd00r/zsh-syntax-highlighting-filetypes

    # Themes and colors
      zi ice depth=1; zi light romkatv/powerlevel10k                          # Powerlevel 10k - main theme
      zi light chrissicool/zsh-256color
      zi light zpm-zsh/colorize                                               # color common commands

    # Wishlist
      # empty

    # # Use caching to make completion for commands such as dpkg and apt usable.
    #   zstyle ':completion::complete:*' use-cache on
    #   zstyle ':completion::complete:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/prezto/zcompcache"

      
    # Completions
      zi load RobSis/zsh-completion-generator
      zi light 3v1n0/zsh-bash-completions-fallback                            # https://github.com/3v1n0/zsh-bash-completions-fallback
      zi wait pack atload=+"zicompinit_fast; zicdreplay" for system-completions
      zi light clarketm/zsh-completions                                       # https://github.com/clarketm/zsh-completions
      # completions from --help
        source $HOME/.zi/plugins/RobSis---zsh-completion-generator/zsh-completion-generator.plugin.zsh 

    # pip completions
      # eval "$(python -m pip completion --zsh)"                              # Currently broken, see https://github.com/pypa/pip/issues/12166

    # zellij completions
      # eval "$(zellij setup --generate-completion zsh)"


    # cleanup
      zicompinit                                                              # <- https://wiki.zshell.dev/docs/guides/commands
      autoload -Uz compinit
      compinit
   


############################################
# END ZI
###############################################################################################################################

###############################################################################################################################
# STUFF THAT GATHERS AT THE BOTTOM OF THE SINK
############################################
  # Atuin
    export ATUIN_NOBIND="true"
    eval "$(atuin init zsh --disable-up-arrow)"
    bindkey '^r' _atuin_search_widget

    # up-arrow, depends on terminal mode
    #  bindkey '^[[A' _atuin_search_widget
    #  bindkey '^[OA' _atuin_search_widget

  # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
    [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

  # enable hash (#) character for line-comments by turning off extended globbing
   # unsetopt extended_glob
   # setopt interactive_comments

  # rtx-cli
    # eval "$(rtx activate zsh)"
    
  # Zoxide (otherwise it interferes with the zi command)
    #eval "$(zoxide init zsh --cmd f)" 
    alias cd="f"
  # Eza
    #alias exa=eza
    alias ls="eza --icons --header --group-directories-first"
    # Handled through abbr

  # free up keybindings for copy/paste in zellij
    bindkey -r "^V"
    bindkey -r "^v"
    bindkey -r "^[v"
    bindkey -r "^[V"
    bindkey -r "^[c"
    bindkey -r "^[C"


  # From Fleek  
    # setopt HIST_FCNTL_LOCK
    # setopt HIST_IGNORE_DUPS
    # unsetopt HIST_IGNORE_ALL_DUPS
    # setopt HIST_IGNORE_SPACE
    # unsetopt HIST_EXPIRE_DUPS_FIRST
    # setopt SHARE_HISTORY
    # unsetopt EXTENDED_HISTORY




  # Aliases
  alias fleeks='cd ~/.local/share/fleek'

  # Named Directory Hashes



# end of zshrc (Debugging reasons, some errors only show the last line)

[ -f "$HOME/.ghcup/env" ] && source "$HOME/.ghcup/env" # ghcup-env

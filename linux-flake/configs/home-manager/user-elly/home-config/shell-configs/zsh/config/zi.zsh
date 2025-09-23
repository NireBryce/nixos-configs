# zi first run must grab the installer from it's website (do not trust auto pulldown)
    # then run:
    
      if [[ -r "${XDG_CONFIG_HOME:-${HOME}/.config}/zi/init.zsh" ]]; then
        source "${XDG_CONFIG_HOME:-${HOME}/.config}/zi/init.zsh" && zzinit
      fi

# TODO: this *should* be fixed by installing zi through zsh, marking this for removal

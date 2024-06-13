# Zi
  # zi first run must grab the installer from it's website
  # then you can:
  
  # zi bootstrap
    if [[ -r "${XDG_CONFIG_HOME:-${HOME}/.config}/zi/init.zsh" ]]; then
      source "${XDG_CONFIG_HOME:-${HOME}/.config}/zi/init.zsh" && zzinit
    fi

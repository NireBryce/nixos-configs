# Zi
  # zi install
    if [[ ! -d "$HOME/.zi" ]]; then
      sh -c "$(curl -fsSL get.zshell.dev)" -- -a loader
    fi

  # zi bootstrap
    if [[ -r "${XDG_CONFIG_HOME:-${HOME}/.config}/zi/init.zsh" ]]; then
      source "${XDG_CONFIG_HOME:-${HOME}/.config}/zi/init.zsh" && zzinit
    fi

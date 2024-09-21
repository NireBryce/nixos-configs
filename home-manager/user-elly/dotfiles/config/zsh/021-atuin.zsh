  export ATUIN_NOBIND="true"
  eval "$(atuin init zsh --disable-up-arrow)"
  bindkey '^r' _atuin_search_widget

{
  imports = [
    ./_dev
    ./_dotfiles
    ./_pkg......nix
    ./_sys......nix # system
    ./_wm......nix  # window manager
    ./_zsh......nix # zsh
  ];
}

# TODO: remove the declarations from individual modules such that you can not have to maintain those when you add/remove packages


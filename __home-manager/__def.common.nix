{
  imports = [
    ./_dev
    ./_dotfiles
    ./_pkg._packages.nix    # user packages
    ./_sys._system.nix      # system
    ./_wm._wm-packages.nix  # window-manager specific packages
    ./_zsh._zsh.nix         # zsh
  ];
}

# TODO: remove the declarations from individual modules such that you can not have to maintain those when you add/remove packages


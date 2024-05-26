{
  imports = [
    ./_dev
    ./_dotfiles
    ./_sys._system.nix          # system
    ./_wm._window-manager.nix   # window-manager specific packages
    ./_zsh._zsh.nix             # zsh
  ];

  nixpkgs.config.allowUnfree = true;                   # Disable if you don't want unfree packages
  nixpkgs.config.allowUnfreePredicate = (_: true);     # Workaround for https://github.com/nix-community/home-manager/issues/2942

  programs.home-manager.enable = true;
}

# TODO: remove the declarations from individual modules such that you can not have to maintain those when you add/remove packages


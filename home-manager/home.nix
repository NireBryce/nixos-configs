{ 
  self,
  ...
}:

let flakePath = self;
in {
  imports = [
  # home manager config fragments
    "${flakePath}/home-manager/dev/default.nix"
    "${flakePath}/home-manager/dotfiles/default.nix"
    "${flakePath}/home-manager/_hm.shells.nix"              # shells
    "${flakePath}/home-manager/_hm.bash.nix"                # bash
  ];
  nixpkgs.config.allowUnfree = true;                   # Disable if you don't want unfree packages
  nixpkgs.config.allowUnfreePredicate = (_: true);     # Workaround for https://github.com/nix-community/home-manager/issues/2942

  programs.home-manager.enable = true;
}

# TODO: remove the declarations from individual modules such that you can not have to maintain those when you add/remove packages 
# REMINDER: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap


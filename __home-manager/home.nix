{ ... }: {
  # Formerly managed by fleek
  # TODO: figure out why this is like this
  nixpkgs = {
    # Configure your nixpkgs instance
    config = {
      
      allowUnfree = true;                   # Disable if you don't want unfree packages
      allowUnfreePredicate = (_: true);     # Workaround for https://github.com/nix-community/home-manager/issues/2942
    };
  };
    programs.home-manager.enable = true;
      
    xdg = {
      enable = true;
    };
}

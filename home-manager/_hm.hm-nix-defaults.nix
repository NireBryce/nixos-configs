{
  lib,
  ...
}:

{
    description = "default options for home-manager and nix-pm";

    nixpkgs.config = {
        allowUnfree          = lib.mkDefault true;  # Disable if you don't want unfree packages
        allowUnfreePredicate = (_: true);           # Workaround for https://github.com/nix-community/home-manager/issues/2942
    };

    programs.home-manager.enable = true;
}

{ pkgs, misc, ... }: {
# Where the nix packages live
# TODO: lib.mkIf lib.mkEnable 
  home.packages = with pkgs;[
    nixfmt
    nil
  ];
}

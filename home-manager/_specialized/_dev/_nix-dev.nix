{ pkgs, misc, ... }: {
# Where the nix packages live
  home.packages = with pkgs;[
    nixfmt
    nil
  ];
}

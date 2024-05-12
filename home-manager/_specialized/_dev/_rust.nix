{ pkgs, misc, ... }: {
# Where the rust packages live
  home.packages = with pkgs; [
    rustc
    # cargo
    # cargo-update
    # cargo-binstall
  ];
}

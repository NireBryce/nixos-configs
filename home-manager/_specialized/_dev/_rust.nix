{ pkgs, misc, ... }: {
# Where the rust packages live
# TODO: lib.mkIf lib.mkEnable 
  home.packages = with pkgs; [
    rustc
    # cargo
    # cargo-update
    # cargo-binstall
  ];
}

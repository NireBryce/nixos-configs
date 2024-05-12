{ pkgs, misc, ... }: {
# Where the haskell packages live
# TODO: lib.mkIf lib.mkEnable 
  home.packages = with pkgs; [
    pkgs.ghc # haskell compiler
    pkgs.haskell-language-server
  ];
}

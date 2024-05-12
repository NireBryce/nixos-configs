{ pkgs, misc, ... }: {
# Where the haskell packages live
  home.packages = with pkgs; [
    pkgs.ghc # haskell compiler
    pkgs.haskell-language-server
  ];
}

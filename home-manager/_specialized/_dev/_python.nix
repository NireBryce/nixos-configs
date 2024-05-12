{ pkgs, misc, ... }: {
# where the python packages live
# TODO: lib.mkIf lib.mkEnable 
  home.packages = with pkgs; [
    python3
    ruff # python linter
    ruff-lsp
  ];
}

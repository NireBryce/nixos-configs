{ pkgs, misc, ... }: {
# where the python packages live
  home.packages = with pkgs; [
    python3
    ruff # python linter
    ruff-lsp
  ];
}

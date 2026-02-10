# lazydocker - TUI docker interface
{ den.bundles.hm.docker =
{ pkgs, ... }:
let packageList = with pkgs; [
    lazydocker
];
in
{
    home.packages = packageList;

    # might require zsh - low priority checkme
}
;}

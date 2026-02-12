# lazydocker - TUI docker interface
{ den.aspects.hm.provides.pkgs-cli = 
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

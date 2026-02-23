# lazydocker - TUI docker interface
{ den.aspects.pkgs-cli.homeManager = 
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

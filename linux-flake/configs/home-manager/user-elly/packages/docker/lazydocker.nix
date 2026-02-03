# lazydocker - TUI docker interface
{ flake.modules.homeManager.packages.docker.lazydocker =
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

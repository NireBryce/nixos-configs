# desc = "TUI docker interface";
{ pkgs, ... }:
let packageList = with pkgs; [
    lazydocker
];
in
{
    home.packages = packageList;
}

# desc = "run commands when file changes";
{ pkgs, ... }:
let packageList = with pkgs; [
    entr
];
in
{
    home.packages = packageList;
}

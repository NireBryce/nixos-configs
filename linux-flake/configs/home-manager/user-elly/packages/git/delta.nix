# desc = "git diff viewer";
{ pkgs, ... }:
let packageList = with pkgs; [
    delta
];
in
{
    home.packages = packageList;
}

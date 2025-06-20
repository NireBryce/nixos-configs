# desc = "git-scm";
{ pkgs, ... }:
let packageList = with pkgs; [
    git
];
in
{
    home.packages = packageList;
}

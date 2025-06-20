# desc = "bash linter";
{ pkgs, ... }:
let packageList = with pkgs; [
    shellcheck
];
in
{
    home.packages = packageList;
}

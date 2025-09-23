# desc = "`diff` utils";
{ pkgs, ... }:
let packageList = with pkgs; [
    diffutils
];
in
{
    home.packages = packageList;
}

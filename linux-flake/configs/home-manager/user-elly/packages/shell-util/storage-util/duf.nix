# desc = "`df` alternative";
{ pkgs, ... }:
let packageList = with pkgs; [
    duf
];
in
{
    home.packages = packageList;
}

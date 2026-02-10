# desc = "`htop` alternative";
{ pkgs, ... }:
{ den.bundles.hm.shell-util =
let packageList = with pkgs; [
    btop
];
in
{
    home.packages = packageList;
}
;}

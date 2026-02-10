# desc = "`df` alternative";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    duf
];
in
{
    home.packages = packageList;
}
;}

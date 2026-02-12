# desc = "`diff` utils";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    diffutils
];
in
{
    home.packages = packageList;
}
;}

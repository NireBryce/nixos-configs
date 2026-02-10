# desc = "`rg` much faster grep alternative";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    ripgrep
];
in
{
    home.packages = packageList;
}
;}

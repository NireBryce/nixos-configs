# vivid - LS_COLORS generator
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    vivid
];
in
{
    home.packages = packageList;
}
;}

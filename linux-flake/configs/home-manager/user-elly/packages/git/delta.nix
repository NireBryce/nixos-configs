# delta - a better git diff viewer
{ den.bundles.hm.git =
{ pkgs, ... }:
let packageList = with pkgs; [
    delta
];
in
{
    home.packages = packageList;
}
;}

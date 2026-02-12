# desc = "midnight commander file browser";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    mc
];

in

{
    home.packages = packageList;
}
;}

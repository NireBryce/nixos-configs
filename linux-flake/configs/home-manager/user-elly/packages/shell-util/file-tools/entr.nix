# desc = "run commands when file changes";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    entr
];
in
{
    home.packages = packageList;
}
;}

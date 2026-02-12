# desc = "`find` alternative";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    fd
];
in
{
    home.packages = packageList;
}
;}

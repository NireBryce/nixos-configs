# desc = "gnu which"; # TODO: better desc
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    which
];
in
{
    home.packages = packageList;
}
;}

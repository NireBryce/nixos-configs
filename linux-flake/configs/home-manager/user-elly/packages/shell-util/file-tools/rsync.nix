# rsync - back in my day we transfered our files uphill both ways
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    rsync
];
in
{
    home.packages = packageList;
}
;}

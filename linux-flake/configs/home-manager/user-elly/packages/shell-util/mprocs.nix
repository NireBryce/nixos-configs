# desc = "run multiple commands in parallel";
{ pkgs, ... }:
{ den.bundles.hm.shell-util =
let packageList = with pkgs; [
    mprocs
];
in
{
    home.packages = packageList;
}
;}

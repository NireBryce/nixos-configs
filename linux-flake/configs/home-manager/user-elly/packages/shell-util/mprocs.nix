# desc = "run multiple commands in parallel";
{ pkgs, ... }:
{ flake.modules.homeManager.packages.shellUtil.mprocs =
let packageList = with pkgs; [
    mprocs
];
in
{
    home.packages = packageList;
}
;}

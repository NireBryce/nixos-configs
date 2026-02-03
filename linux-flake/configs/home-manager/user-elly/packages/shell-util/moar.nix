# desc = "better pager for some things https://github.com/walles/moor";
{ flake.modules.homeManager.packages.pagers.moor =
{ pkgs, ... }:
let packageList = with pkgs; [
    moor # moar renamed to moor https://github.com/walles/moor/pull/305
];
in
{
    home.packages = packageList;
}
;}

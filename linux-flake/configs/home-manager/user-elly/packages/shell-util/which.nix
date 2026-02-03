# desc = "gnu which"; # TODO: better desc
{ flake.modules.homeManager.packages.shellUtil.which =
{ pkgs, ... }:
let packageList = with pkgs; [
    which
];
in
{
    home.packages = packageList;
}
;}

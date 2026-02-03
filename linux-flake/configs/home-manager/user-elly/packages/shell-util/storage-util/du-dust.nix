# desc = "`du` alternative";
{ flake.modules.homeManager.commonLinux.shellUtil.storage.du-dust =
{ pkgs, ... }:
let packageList = with pkgs; [
    dust
];
in
{
    home.packages = packageList;
}
;}

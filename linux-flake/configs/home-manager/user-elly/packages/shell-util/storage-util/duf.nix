# desc = "`df` alternative";
{ flake.modules.homeManager.commonLinux.shellUtil.storage.duf =
{ pkgs, ... }:
let packageList = with pkgs; [
    duf
];
in
{
    home.packages = packageList;
}
;}

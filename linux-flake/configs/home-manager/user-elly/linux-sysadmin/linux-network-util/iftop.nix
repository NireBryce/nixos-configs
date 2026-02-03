# desc = "network monitor https://pdw.ex-parrot.com/iftop/";
{ flake.modules.homeManager.commonLinux.networkUtil.iftop =
{ pkgs, ... }:
let packageList = with pkgs; [
    iftop
];
in
{
    home.packages = packageList;
}
;}

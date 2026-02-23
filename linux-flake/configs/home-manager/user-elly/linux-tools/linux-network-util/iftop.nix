# desc = "network monitor https://pdw.ex-parrot.com/iftop/";
{ den.aspects.linux-tools.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    iftop
];
in
{
    home.packages = packageList;
}
;}

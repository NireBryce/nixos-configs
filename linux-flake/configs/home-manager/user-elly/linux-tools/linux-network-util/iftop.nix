# desc = "network monitor https://pdw.ex-parrot.com/iftop/";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
let packageList = with pkgs; [
    iftop
];
in
{
    home.packages = packageList;
}
;}

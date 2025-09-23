# desc = "network monitor https://pdw.ex-parrot.com/iftop/";
{ pkgs, ... }:
let packageList = with pkgs; [
    iftop
];
in
{
    home.packages = packageList;
}

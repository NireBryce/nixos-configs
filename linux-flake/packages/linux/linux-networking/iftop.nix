# desc = "network monitor https://pdw.ex-parrot.com/iftop/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        iftop
    ];
}

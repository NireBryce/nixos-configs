# desc = "discord chat https://discord.com/";
{ pkgs, ... }:
let packageList = with pkgs; [
    discord
];
in
{
    home.packages = packageList;
}

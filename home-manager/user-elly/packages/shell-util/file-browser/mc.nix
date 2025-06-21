# desc = "midnight commander file browser";
{ pkgs, ... }:
let packageList = with pkgs; [
    mc
];
in
{
    home.packages = packageList;
}

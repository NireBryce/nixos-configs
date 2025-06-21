# desc = "LS_COLORS generator";
{ pkgs, ... }:
let packageList = with pkgs; [
    vivid
];
in
{
    home.packages = packageList;
}

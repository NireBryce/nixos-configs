# desc = "back in my day we transfered our files uphill both ways";
{ pkgs, ... }:
let packageList = with pkgs; [
    rsync
];
in
{
    home.packages = packageList;
}

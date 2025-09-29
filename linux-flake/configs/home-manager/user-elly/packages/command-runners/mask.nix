# desc = "mask - markdown task runner";
{ pkgs, ... }:
let packageList = with pkgs; [
    mask
];
in
{
    home.packages = packageList;
}

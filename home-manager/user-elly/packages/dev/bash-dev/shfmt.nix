# desc = "bash formatter";
{ pkgs, ... }:
let packageList = with pkgs; [
    shfmt
];
in
{
    home.packages = packageList;
}

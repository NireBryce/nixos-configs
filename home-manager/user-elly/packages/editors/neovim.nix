# desc = "neovim editor";
{ pkgs, ... }:
let packageList = with pkgs; [
    neovim
];
in
{
    home.packages = packageList;
}

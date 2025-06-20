# desc = "github-cli";
{ pkgs, ... }:
let packageList = with pkgs; [
    gh
];
in
{
    home.packages = packageList;
}

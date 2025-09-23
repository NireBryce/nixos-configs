# desc = "commitizen"; # TODO: better description
{ pkgs, ... }:
let packageList = with pkgs; [
    commitizen
];
in
{
    home.packages = packageList;
}

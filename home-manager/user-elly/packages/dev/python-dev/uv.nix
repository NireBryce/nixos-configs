# desc = "python version- and venv-manager ";
{ pkgs, ... }:
let packageList = with pkgs; [
    uv
];
in
{   
    home.packages = packageList;
}

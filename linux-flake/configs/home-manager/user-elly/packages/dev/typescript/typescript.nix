# desc = "python version- and venv-manager ";
{ pkgs, ... }:
let packageList = with pkgs; [
    typescript
];
in
{   
    home.packages = packageList;
}

# uv - python version-, venv-, and packaging-management tool
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    uv
];
in
{   
    home.packages = packageList;
}
;}

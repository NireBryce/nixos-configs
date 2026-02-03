# uv - python version-, venv-, and packaging-management tool
{ flake.modules.homeManager.development.python.uv =
{ pkgs, ... }:
let packageList = with pkgs; [
    uv
];
in
{   
    home.packages = packageList;
}
;}

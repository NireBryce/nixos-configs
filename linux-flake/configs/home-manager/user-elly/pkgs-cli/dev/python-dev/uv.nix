# uv - python version-, venv-, and packaging-management tool
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    uv
];
in
{   
    home.packages = packageList;
}
;}

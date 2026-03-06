# uv - python version-, venv-, and packaging-management tool
{ pkgs, ... }:
{   
    home.packages = with pkgs; [
        uv
    ];
}

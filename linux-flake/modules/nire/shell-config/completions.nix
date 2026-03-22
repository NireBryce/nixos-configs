{ self, inputs, ...}:
{ flake.homeModules.shell-config = 
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        cod
    ];
}
;}  

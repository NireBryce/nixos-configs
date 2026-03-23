{ self, inputs, ...}:
{ flake.modules.homeManager.shell-config = 
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        cod
    ];
}
;}  

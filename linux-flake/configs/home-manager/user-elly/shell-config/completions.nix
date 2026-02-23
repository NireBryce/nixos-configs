{ den.aspects.shell-config.homeManager = 
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        cod
    ];
}
;}  

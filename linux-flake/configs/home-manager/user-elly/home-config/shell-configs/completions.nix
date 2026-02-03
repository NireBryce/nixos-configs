{ flake.modules.homeManager.common.shells.completions = # 1
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        cod
    ];
}
;}  

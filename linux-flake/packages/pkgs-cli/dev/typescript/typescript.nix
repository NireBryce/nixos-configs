# typescript - it's typescript
{ pkgs, ... }:
{   
    home.packages = with pkgs; [
        typescript
    ];
}

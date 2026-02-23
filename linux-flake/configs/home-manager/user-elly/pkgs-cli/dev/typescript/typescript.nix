# typescript - it's typescript
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    typescript
];
in
{   
    home.packages = packageList;
}
;}

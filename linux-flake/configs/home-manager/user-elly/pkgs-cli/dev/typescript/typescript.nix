# typescript - it's typescript
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    typescript
];
in
{   
    home.packages = packageList;
}
;}

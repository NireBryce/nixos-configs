# rsync - back in my day we transfered our files uphill both ways
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    rsync
];
in
{
    home.packages = packageList;
}
;}

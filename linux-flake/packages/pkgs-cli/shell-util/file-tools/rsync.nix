# rsync - back in my day we transfered our files uphill both ways
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        rsync
    ];
}

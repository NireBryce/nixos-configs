# desc = "run multiple commands in parallel";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        mprocs
    ];
}

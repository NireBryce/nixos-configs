# desc = "run multiple commands in parallel";
{ pkgs, ... }:
let packageList = with pkgs; [
    mprocs
];
in
{
    home.packages = packageList;
}

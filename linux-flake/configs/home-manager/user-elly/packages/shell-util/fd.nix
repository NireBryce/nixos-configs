# desc = "`find` alternative";
{ pkgs, ... }:
let packageList = with pkgs; [
    fd
];
in
{
    home.packages = packageList;
}

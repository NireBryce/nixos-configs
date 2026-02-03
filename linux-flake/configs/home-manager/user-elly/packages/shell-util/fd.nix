# desc = "`find` alternative";
{ flake.modules.homeManager.packages.shellUtil.fd =
{ pkgs, ... }:
let packageList = with pkgs; [
    fd
];
in
{
    home.packages = packageList;
}
;}

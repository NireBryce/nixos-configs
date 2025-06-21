# desc = "python linter";
{ pkgs, ... }:
let packageList = with pkgs; [
    ruff
];
in
{
    home.packages = packageList;
}

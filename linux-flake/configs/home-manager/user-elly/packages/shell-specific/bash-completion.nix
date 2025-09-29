# desc = "bash completions";
{ pkgs, ... }:
let packageList = with pkgs; [
    bash-completion
];
in
{
    home.packages = packageList;
}

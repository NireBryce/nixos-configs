# desc = "  ";
{ flake.modules.homeManager.packages.browser.firefox =
{ pkgs, ... }:
{
    # todo: this is also installed as a system package, does that matter?
    home.packages = with pkgs; [ firefox ];
}
;}

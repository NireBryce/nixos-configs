# desc = "  ";
{ flake.modules.homeManager.packages.browser.chrome =
{ pkgs, ... }:
{
    # todo: this is also installed as a system package, does that matter?
    home.packages = with pkgs; [ google-chrome ];
}
;}

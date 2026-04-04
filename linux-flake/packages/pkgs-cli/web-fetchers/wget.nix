# desc = "its like curl but different https://www.gnu.org/software/wget/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        wget
    ];
}

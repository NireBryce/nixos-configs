{ pkgs, ... }:
{
    # network monitor https://pdw.ex-parrot.com/iftop/
    home.packages = with pkgs; [
        iftop
    ];
}

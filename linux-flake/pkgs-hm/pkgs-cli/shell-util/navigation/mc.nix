# desc = "midnight commander file browser";
{ pkgs, ... }:


{
    home.packages = with pkgs; [
        mc
    ];
}

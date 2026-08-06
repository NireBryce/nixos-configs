{ config, ... }:
{
    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.font ];

    flake.modules.nixos.font = 
{ pkgs, ...}: 
{
    fonts = {
        packages = with pkgs; [
            nerd-fonts.jetbrains-mono
            nerd-fonts.iosevka
            nerd-fonts.fira-code
        ];
        fontconfig = {
            enable = true;
            ## fix firefox and GTK emoji rendering issues https://discourse.nixos.org/t/firefox-doesnt-render-noto-color-emojis/51202/2
            useEmbeddedBitmaps = true;
        };
    };
}
;}

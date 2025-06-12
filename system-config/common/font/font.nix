{
    pkgs,
    ...
}:

{
    fonts = {
        packages = with pkgs; [
            nerd-fonts.jetbrains-mono
            nerd-fonts.iosevka
            nerd-fonts.fira-code
        ];

        ## fix firefox and GTK emoji rendering issues https://discourse.nixos.org/t/firefox-doesnt-render-noto-color-emojis/51202/2
        useEmbeddedBitmaps = true;
    };
}

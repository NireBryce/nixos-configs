{ pkgs, ...}:

{
    fonts.fontconfig.enable = true;

    home.packages = with pkgs; [    # TODO: figure out which should be modularized for, say, headless machines
        nerd-fonts.fira-code
        nerd-fonts.iosevka
        nerd-fonts.jetbrains-mono
    ];
}

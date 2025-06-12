{ pkgs, ...}:

{
    home.packages = with pkgs; [    # TODO: duplicated in system fonts, please remove
        nerd-fonts.fira-code
        nerd-fonts.iosevka
        nerd-fonts.jetbrains-mono
    ];
}

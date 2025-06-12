{ pkgs, ...}:

{
    # TODO: duplicated in system fonts, is this for non-nix hosts? consider moving to there
    home.packages = with pkgs; [            
        nerd-fonts.fira-code
        nerd-fonts.iosevka
        nerd-fonts.jetbrains-mono
    ];
}

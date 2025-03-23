{
    pkgs,
    ...
}:

{
  ## Fonts
    fonts.packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        nerd-fonts.iosevka
        nerd-fonts.fira-code
    ];
}

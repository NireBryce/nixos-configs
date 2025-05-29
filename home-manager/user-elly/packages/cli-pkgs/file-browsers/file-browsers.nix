{
    pkgs,
    ...
}:
 
{
    home.packages = with pkgs;[
        mc                            # midnight commander TUI file manager       https://www.midnight-commander.org/
    ];
}

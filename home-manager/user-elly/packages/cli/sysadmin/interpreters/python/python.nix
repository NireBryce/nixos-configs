{
    pkgs,
    ...
}:
 
{
    home.packages = with pkgs;[
        python3                       # system python, zsh complains without      https://python.org
    ];
}

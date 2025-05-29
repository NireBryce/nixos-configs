{
    pkgs,
    ...
}:
 
{
    home.packages = with pkgs;[
        nushell                       # nushell -c for tabular display any shell  https://github.com/nushell/nushell
    ];
}

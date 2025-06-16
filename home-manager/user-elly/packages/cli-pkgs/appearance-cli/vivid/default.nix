{
    pkgs,
    ...
}:
 
{
    home.packages = with pkgs;[
        vivid
    ];
}

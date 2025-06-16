{
    pkgs,
    ...
}:
 
{
    home.packages = with pkgs;[
        mask
    ];
}

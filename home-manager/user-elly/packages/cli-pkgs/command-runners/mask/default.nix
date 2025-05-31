{
    pkgs,
    ...
}:
 
{
    imports = [
        
    ];
    home.packages = with pkgs;[
        mask
    ];
}

{
    pkgs,
    ...
}:
 
{
    imports = [
        ./storage-stats.nix
    ];
    home.packages = with pkgs;[
        du-dust                       # `du` alternative                          https://github.com/bootandy/dust
        duf                           # `df` alternative                          https://github.com/muesli/duf
    ];
}

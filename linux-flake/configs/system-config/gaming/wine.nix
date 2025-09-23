{
    pkgs,
    ...
}:

{
    environment.systemPackages = with pkgs; [            
        wineWowPackages.waylandFull # Wine for wayland                          https://www.winehq.org/
    ];
}

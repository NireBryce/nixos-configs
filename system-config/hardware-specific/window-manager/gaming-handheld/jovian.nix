{
    config,
    pkgs,
    lib,
    ...
}:
let 
_deckyLoaderPackages = with pkgs; [
    power-profiles-daemon
    inotify-tools
    libpulseaudio
    coreutils
    gamescope
    gamemode
    mangohud
    pciutils
    systemd
    gnugrep
    python3
    gnused
    procps
    steam
    gawk
    file
 ];
_deckyLoaderPyPackages = pythonPkgs: with pythonPkgs; [
    click
];

# TODO: 2025-04-07 22:10 EDT why does decky not show up in steamOS
 in {
    systemd.services.decky-loader.environment.LD_LIBRARY_PATH = lib.makeLibraryPath config.jovian.decky-loader.extraPackages;
    services.desktopManager.plasma6.enable = true;
    
    jovian = {
        steam = {
            enable              = true;
            autoStart           = true;
            desktopSession      = "plasma";
            steam.user          = "elly";
        };
        hardware.has.amd.gpu    = true;

        decky-loader = {
            enable              = true;
            extraPythonPackages = _deckyLoaderPyPackages;
            extraPackages       = _deckyLoaderPackages;
        };
    };
    
}
    # https://github.com/gradientvera/GradientOS/blob/adcc4892703dc2129fc8f16d0bce56c2146cd788/mixins/jovian-decky-loader.nix#L5


        # Early modesetting
        # jovian.hardware.amd.gpu.enableEarlyModesetting = true;

        # ease backlight permissions for auto-dimming
        # jovian.hardware.amd.gpu.enableBacklightControl = true;


        # https://github.com/ciarandg/portfolio/blob/a45bfbd2ba95148a6df6cfcbba62b3e814364d4c/content/posts/nixos-steam-box/index.md?plain=1#L81
        # services.displayManager.defaultSession = "plasma";        # TODO: remove this, it's meant to select for plasma6 but plasma 6 is the default now
        
    # users = {
    #     groups.deck = {
    #         name = "deck";
    #         gid = 10000;
    #     };
    #     users.deck = {
    #         description = "steamos";
    #         extraGroups = [ "gamemode" "networkmanager" ];
    #         group = "deck";
    #         passwordFile = /persist/passwords/deck;
    #         home = /home/deck;
    #         isNormalUser = true;
    #         uid = 10000;
    #     };
    # };


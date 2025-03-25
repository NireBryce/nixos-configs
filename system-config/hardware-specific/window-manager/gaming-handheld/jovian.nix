{
    lib,
    ...
}:

{
    jovian.steam.enable = true;
    jovian.steam.autoStart = true;
    jovian.steam.desktopSession = "plasma";
    jovian.steam.user = "deck";

    # TODO: I think this is for GPUs and not APUs, enable if it doesn't work.
    # jovian.hardware.has.amd.gpu = true;


    # https://github.com/ciarandg/portfolio/blob/a45bfbd2ba95148a6df6cfcbba62b3e814364d4c/content/posts/nixos-steam-box/index.md?plain=1#L81
    services.displayManager.defaultSession = "plasma";        # TODO: remove this, it's meant to select for plasma6 but plasma 6 is the default now
    services.desktopManager.plasma6.enable = true;
    

    # jovian.decky-loader.enable = true;
    #  $ touch ~/.steam/steam/.cef-enable-remote-debugging  https://github.com/Jovian-Experiments/Jovian-NixOS/issues/460#issuecomment-2599835660
}

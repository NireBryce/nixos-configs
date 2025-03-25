{
    lib,
    ...
}:

{
    jovian.steam.enable = true;
    jovian.steam.autoStart = true;
    jovian.steam.desktopSession = "plasma";
    jovian.steam.user = "deck";
    services.displayManager.sddm.enable = lib.mkForce false;
    services.displayManager.sddm.wayland.enable = lib.mkForce false;
    # jovian.steam.enable = true;
    # jovian.decky-loader.enable = true;
    #  $ touch ~/.steam/steam/.cef-enable-remote-debugging  https://github.com/Jovian-Experiments/Jovian-NixOS/issues/460#issuecomment-2599835660
}

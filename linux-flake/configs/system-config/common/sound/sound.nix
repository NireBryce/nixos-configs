{
    pkgs,
    ...
}:

{
    security.rtkit.enable       = true;                       # TODO: "rtkit is optional but recommended."  I forget why I wrote this
    hardware.bluetooth.package  = pkgs.bluez5-experimental;
    services.pipewire = {
        enable              = true;
        wireplumber.enable  = true;
        alsa.enable         = true;
        alsa.support32Bit   = true;
        pulse.enable        = true;
    };

    services.pipewire.wireplumber.configPackages = [
        (pkgs.writeTextDir "wireplumber/bluetooth.lua.d/51-bluez-config.lua" ''
            bluez_monitor.properties = { 
                ["bluez6.enable-sbc-xq"]    = true,
                ["bluez6.enable-msbc"]      = true,
                ["bluez6.enable-hw-volume"] = true,
                ["bluez6.headset-roles"]    = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
            }''
        )
    ];

  #? from https://github.com/jpas/etc-nixos/blob/365e5301e559af29eafec7f7c391f1c84b6c6477/profiles/hardware/sound.nix#L18
    systemd.user.services.pipewire-pulse = {
        bindsTo = [ "pipewire.service" ];
        after   = [ "pipewire.service" ];
    };
    #? pipewire also set in graphics.extraPackages presumably for hdmi/displayport audio
}

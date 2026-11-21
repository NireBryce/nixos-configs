# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    nixos = { pkgs, ... }: {
        security.rtkit.enable = true; # https://nixos.wiki/wiki/PipeWire
        hardware.bluetooth.package = pkgs.bluez5-experimental;
        services.pipewire = {
            enable = true;
            wireplumber.enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
        };
        # WirePlumber 0.5+ reads `wireplumber.conf.d`, not the 0.4 Lua
        # `bluetooth.lua.d` file this module used to ship, whose
        # `bluez6.*` keys were also misspelled (`bluez5.*`): none of it
        # applied (issue #674). Not yet confirmed on a headset;
        # `wpctl status` after a switch shows the codec.
        services.pipewire.wireplumber.extraConfig."51-bluez-config" = {
            "monitor.bluez.properties" = {
                "bluez5.enable-sbc-xq"    = true;
                "bluez5.enable-msbc"      = true;
                "bluez5.enable-hw-volume" = true;
                "bluez5.roles"            = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
            };
        };

        # from https://github.com/jpas/etc-nixos/blob/365e5301e559af29eafec7f7c391f1c84b6c6477/profiles/hardware/sound.nix#L18
        systemd.user.services.pipewire-pulse = {
            bindsTo = [ "pipewire.service" ];
            after = [ "pipewire.service" ];
        };
        # pipewire also set in graphics.extraPackages presumably for hdmi/displayport
        # audio
    };
}

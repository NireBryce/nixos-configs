{ ... }:
{
  # Remove sound.enable or set it to false if you had it set previously, as sound.enable is only meant for ALSA-based configurations
  
  # rtkit is optional but recommended
  security.rtkit.enable = true;
  hardware.pulseaudio.enable = mkForce false;
  
  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };

  # from https://github.com/jpas/etc-nixos/blob/365e5301e559af29eafec7f7c391f1c84b6c6477/profiles/hardware/sound.nix#L18
  systemd.user.services.pipewire-pulse = {
    bindsTo = [ "pipewire.service" ];
    after = [ "pipewire.service" ];
  };
  hardware.opengl = {
    extraPackages = [ pkgs.pipewire ];
  };

  # Recent fix for pipewire-pulse breakage
  # systemd.user.services.pipewire-pulse.path = [ pkgs.pulseaudio ];

  sound.enable = false;
  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "wireplumber/bluetooth.lua.d/51-bluez-config.lua" ''
    bluez_monitor.properties = { 
      ["bluez6.enable-sbc-xq"] = true,
      ["bluez6.enable-msbc"] = true,
      ["bluez6.enable-hw-volume"] = true,
      ["bluez6.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
    }
  '')
  ];
}

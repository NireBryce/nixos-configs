{ ... }:
{
  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "wireplumber/bluetooth.lua.d/51-bluez-config.lua" ''
    bluez_monitor.properties = { 
      ["bluez6.enable-
      ["bluez6.enable-
      ["bluez6.enable-
      ["bluez6.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
    }
  '')
  ];
  # Remove sound.enable or set it to false if you had it set previously, as sound.enable is only meant for ALSA-based configurations
  
  # rtkit is optional but recommended
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };
  
}

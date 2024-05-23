{ 
  pkgs,
  ...
}:
{
  # pipewire
  security.rtkit.enable = true;                     # rtkit is optional but recommended
  hardware.bluetooth.package = pkgs.bluez5-experimental;
  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };
  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "wireplumber/bluetooth.lua.d/51-bluez-config.lua" ''
      bluez_monitor.properties = { 
        ["bluez6.enable-sbc-xq"] = true,
        ["bluez6.enable-msbc"] = true,
        ["bluez6.enable-hw-volume"] = true,
        ["bluez6.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
      }''
    )
  ];
  # from https://github.com/jpas/etc-nixos/blob/365e5301e559af29eafec7f7c391f1c84b6c6477/profiles/hardware/sound.nix#L18
  systemd.user.services.pipewire-pulse = {
    bindsTo = [ "pipewire.service" ];
    after = [ "pipewire.service" ];
  };
  hardware.opengl = {
    extraPackages = [ pkgs.pipewire ];
  };
  environment.packages = with pkgs; [
    wireplumber                             # The 'enable' up there should work, but just in case.
  ];
}

  
  
    
    
    


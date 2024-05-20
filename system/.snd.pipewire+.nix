# Pipewire config, including pulse and alsa compatability
  # Remove sound.enable or set it to false if you had it set previously, as sound.enable is only meant for ALSA-based configurations
{ pkgs, lib, config, ... }:
{
  options = {
    _pipewire.enable = lib.mkEnableOption "Enables Pipewire";
  };
  config = lib.mkIf config._pipewire.enable {
    # rtkit is optional but recommended
    security.rtkit.enable = true;
    
    
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


    # from https://github.com/PaulGrandperrin/nix-systems/blob/17fcd927fd37508cd8222b5784f38451e33c85de/nixosModules/shared/desktop.nix#L123
    # systemd.user.services.pipewire-pulse.path = [ pkgs.pulseaudio ]; # HACK waiting for #165125
  };

  



  
}


# sound.enable = true; # ALSA-based sound
# hardware.pulseaudio.enable = mkForce false;

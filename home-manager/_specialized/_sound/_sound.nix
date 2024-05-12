{ pkgs, lib, config, ... }: {
  # TODO: lib.mkIf lib.mkEnable sound
  options = {
    _sound.enable = lib.mkEnableOption "Enables sound packages";
  };
  config = lib.mkIf config._sound.enable {    
    home.packages = with pkgs; [
      # pipewire
      wireplumber
    ];
  };
}

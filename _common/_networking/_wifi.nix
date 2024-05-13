{ lib, config, ... }: 
{ 
  options = {
    _wifi.enable = lib.mkEnableOption "Enables wifi settings";
  };
  config = lib.mkIf config._wifi.enable {
    # Wifi
    networking.networkmanager.enable = true;  # Needs to be 'true' for KDE networking
  };
}

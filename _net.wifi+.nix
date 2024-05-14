{ lib, config, ... }: 
{ 
  options = {
    _wifi.enable = lib.mkEnableOption "Enables wifi settings";
  };
  # Wifi
  config = lib.mkIf config._wifi.enable {
    networking.networkmanager.enable = true;  # Needs to be 'true' for KDE networking
  };
}

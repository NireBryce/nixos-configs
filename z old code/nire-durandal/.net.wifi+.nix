{ lib, config, ... }: 
{ 
  # Wifi
  config = lib.mkIf config._wifi.enable {
    networking.networkmanager.enable = true;  # Needs to be 'true' for KDE networking
  };
}

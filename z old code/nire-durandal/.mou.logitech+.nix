# I use `piper` to manage my logitech g600, system settings required for it go here
{ lib, config, ... }:
{

  options = {
    _logitech.enable = lib.mkEnableOption "Enables logitech and razer mouse settings";
  };
  config = lib.mkIf config._logitech.enable {
    
  };
}


# from https://guekka.github.io/nixos-server-2/
{ config, lib, pkgs, ... }:
{
  with lib; let
    cfg = config.services.tailscaleAutoconnect; 
  in {
    options = {
      services.tailscaleAutoconnect = {
        enable = mkEnableOption "tailscaleAutoconnect";
      };
    };

    config = mkIf cfg.services.tailscaleAutoconnect.enable {
      # ...
    };
  };
}

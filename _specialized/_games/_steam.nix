# Steam (valve) app settings
{ lib, config, ... }:
{
  options = {
    _steam.enable = lib.mkEnableOption "Enables Steam (games)";
  };
  config = lib.mkIf config._steam.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      gamescopeSession.enable = true; # third party gamescope compositor
    }; 
  };
}

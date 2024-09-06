{
  pkgs,
  ...
}:
{
## Sunshine https://www.reddit.com/r/NixOS/comments/1bq2bx4/beginners_guide_to_sunshine_gamedesktop_streaming/
  environment.systemPackages = with pkgs; [
    sunshine
    moonlight-qt
  ];
  ## Avahi
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;
  

  security.wrappers.sunshine = {
      owner = "root";
      group = "root";
      capabilities = "cap_sys_admin+p";
      source = "${pkgs.sunshine}/bin/sunshine";
  };
  
  networking.firewall = {

    allowedTCPPorts = [ # ## Sunshine
      47984 
      47989 
      47990 
      48010 
    ];
    allowedUDPPortRanges = [
      { from = 47998; to = 48000; }
    ];
  };
}

# in tailscale.nix
# from https://guekka.github.io/nixos-server-2/
{ 
  config,
  lib,
  self,
  ...
}: 

{
  imports = [
    # TODO: fixme
    # outputs.nixosModules.tailscale-autoconnect
    "${self}/___modules/tailscale-autoconnect.nix"
  ];
  services.tailscaleAutoconnect = {
    enable = true;
    authkeyFile = config.sops.secrets.tailscale_key.path; # TODO: Why can't this be in the sops file? it broke something
    loginServer = "https://login.tailscale.com";
    advertiseExitNode = lib.mkDefault false;
  };

  sops.secrets.tailscale_key = {
    sopsFile =  "${self}/system-config/secrets/secrets.yaml"; 
  };

  environment.persistence = {
    "/persist".directories = ["/var/lib/tailscale"];
  };
}


# { outputs, ...}:
# {
#   imports = [
#     outputs.nixosModules.tailscale-autoconnect
#   ];

#   services.tailscaleAutoconnect = {
#     enable = true;
#     authkeyFile = config.sops.secrets.tailscale_key.path;
#     loginServer = "https://login.tailscale.com";
#     exitNode = "some-node-id";
#     exitNodeAllowLanAccess = true;
#   };

#   sops.secrets.tailscale_key = {
#     sopsFile = ./secrets.yaml;
#   };

#   environment.persistence = {
#     "/persist".directories = ["/var/lib/tailscale"];
#   };
# }

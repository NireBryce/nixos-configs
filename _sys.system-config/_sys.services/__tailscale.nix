# in <host>/tailscale.nix
# from https://guekka.github.io/nixos-server-2/
{ 
  config,
  outputs,
  lib,
  ...
}: 

{
  imports = [
    outputs.nixosModules.tailscale-autoconnect
    # ../../___modules/tailscale-autoconnect.nix
  ];
  services.tailscaleAutoconnect = {
    enable = true;
    authkeyFile = config.sops.secrets.tailscale_key.path;
    loginServer = "https://login.tailscale.com";
    advertiseExitNode = lib.mkDefault false;
  };

  # sops.secrets.tailscale_key = {
  #   sopsFile =  ../_sys.sec.secrets/secrets.yaml; 
  # };

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

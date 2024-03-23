# in <host>/tailscale.nix
# from https://guekka.github.io/nixos-server-2/
{ 
  config,
  pkgs,
  outputs,
  ...
}: {
  imports = [outputs.nixosModules.tailscale-autoconnect];

  services.tailscaleAutoconnect = {
    enable = true;

    authkeyFile = config.sops.secrets.tailscale_key.path;
    loginServer = "https://login.tailscale.com";
    advertiseExitNode = false;
  };

  sops.secrets.tailscale_key = {
    sopsFile =   sopsPath; 
    # TODO: this needs fixing, need to figure out how to do it per-host
    # Unless it's this simple
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

# From https://guekka.github.io/nixos-server-2/
# { config, lib, pkgs, ... }:
# {
#   with lib; let
#     cfg = config.services.tailscaleAutoconnect; 
#   in {
#     options = {
#       services.tailscaleAutoconnect = {
#         enable = mkEnableOption "tailscaleAutoconnect";
#       };
#     };

#     config = mkIf cfg.services.tailscaleAutoconnect.enable {
#       # ...
#     };
#   };
# }
# This is the basic structure of a module. We declare an option, and then we use 
# it to conditionally change the configuration. So:
#
#  - What we write in options is the option declaration
#  - What we write in config is the consequence of the option being enabled, 
#    the configuration change
#
# Let’s declare all the options first.
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.tailscaleAutoconnect; 
in {
  options.services.tailscaleAutoconnect = {
    enable = mkEnableOption "tailscaleAutoconnect";
    authkeyFile = mkOption {
      type = types.str;
      description = "The authkey to use for authentication with Tailscale";
    };

    loginServer = mkOption {
      type = types.str;
      default = "";
      description = "The login server to use for authentication with Tailscale";
    };

    advertiseExitNode = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to advertise this node as an exit node";
    };

    exitNode = mkOption {
      type = types.str;
      default = "";
      description = "The exit node to use for this node";
    };

    exitNodeAllowLanAccess = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to allow LAN access to this node";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.authkeyFile != "";
        message = "authkeyFile must be set";
      }
      {
        assertion = cfg.exitNodeAllowLanAccess -> cfg.exitNode != "";
        message = "exitNodeAllowLanAccess must be false if exitNode is not set";
      }
      {
        assertion = cfg.advertiseExitNode -> cfg.exitNode == "";
        message = "advertiseExitNode must be false if exitNode is set";
      }
    ];
    systemd.services.tailscale-autoconnect = {
      description = "Automatic connection to Tailscale";

      # make sure tailscale is running before trying to connect to tailscale
      after = ["network-pre.target" "tailscale.service"];
      wants = ["network-pre.target" "tailscale.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig.Type = "oneshot";

      script = with pkgs; ''
        # wait for tailscaled to settle
        sleep 2

        # check if we are already authenticated to tailscale
        status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
        # if status is not null, then we are already authenticated
        echo "tailscale status: $status"
        if [ "$status" != "NeedsLogin" ]; then
            exit 0
        fi

        # otherwise authenticate with tailscale
        # timeout after 10 seconds to avoid hanging the boot process
        ${coreutils}/bin/timeout 10 ${tailscale}/bin/tailscale up \
          ${lib.optionalString (cfg.loginServer != "") "--login-server=${cfg.loginServer}"} \
          --authkey=$(cat "${cfg.authkeyFile}")

        # we have to proceed in two steps because some options are only available
        # after authentication
        ${coreutils}/bin/timeout 10 ${tailscale}/bin/tailscale up \
          ${lib.optionalString (cfg.loginServer != "") "--login-server=${cfg.loginServer}"} \
          ${lib.optionalString (cfg.advertiseExitNode) "--advertise-exit-node"} \
          ${lib.optionalString (cfg.exitNode != "") "--exit-node=${cfg.exitNode}"} \
          ${lib.optionalString (cfg.exitNodeAllowLanAccess) "--exit-node-allow-lan-access"}
      '';
    };
    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };

    services.tailscale = {
      enable = true;
      useRoutingFeatures = if cfg.advertiseExitNode then "server" else "client";
    };
  };
}

# First, the assertions. They’re here to make sure that the user doesn’t make 
# any mistake when configuring the module. For example, a user cannot both 
# advertise an exit node and set an exit node. Then, the service. We’re using 
# systemd to run a script that will connect to Tailscale. The after, wants and 
# wantedBy options make the script run after the network is up and after 
# Tailscale daemon is started. The Type option is here to make sure that the
# script is run only once. The script itself is a bit long, but it’s just 
# a bunch of bash commands. 
# 
# It’s pretty straightforward. First, we wait for the 
# Tailscale daemon to settle. Then, we check if we’re already authenticated. 
# If we are, we exit. Otherwise, we authenticate. Finally, we connect 
# to Tailscale. We have to do it in two steps because some options are only 
# available after authentication.
# 
# At the end, we configure the firewall to allow Tailscale traffic, and we enable the Tailscale service.
#
# Now, an example of how to use this module:
#
# # in <host>/tailscale.nix
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


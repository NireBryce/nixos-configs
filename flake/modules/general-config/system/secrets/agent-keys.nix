# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
# summary: Materializes this host's agent SSH key from sops for elly at activation.
{ lib, ... }:
let
    # Hosts with an agent-keys/<host>.yaml under this directory (recipients
    # per file in .sops.yaml). Hosts not listed materialize nothing.
    agentKeyHosts = [
        "nire-cube"
        "nire-durandal"
        "nire-lysithea"
        "nire-tenacity"
    ];
in {
    nixos = { config, ... }: {
        # One agent key per host, each sops file encrypted to that host's
        # key only, so a host materializes and can only read its own.
        # Readable by elly because agent tooling runs as elly; what the key
        # may do is bounded by the authorizedKeys options in ssh.nix.
        sops.secrets."agent-ssh-key" = lib.mkIf (builtins.elem config.networking.hostName agentKeyHosts) {
            sopsFile = ./. + "/agent-keys/${config.networking.hostName}.yaml";
            owner = "elly";
            mode = "0600";
        };
    };
}

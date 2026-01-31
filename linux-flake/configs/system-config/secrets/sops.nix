# sops secret management
{
    config,
    ...
}:
let
    isEd25519   = k: k.type == "ed25519";
    getKeyPath  = k: k.path;
    keys        = builtins.filter isEd25519 config.services.openssh.hostKeys;

    secretsPath = ./secrets.yaml;

in {
    flake.modules.nixos.secrets.sops = { sops-nix, pkgs, ... }: {


        imports     = [
            sops-nix.nixosModules.sops
        ];

        environment.systemPackages = with pkgs; [
            sops
        ];

        sops = {
            age.sshKeyPaths = map getKeyPath keys;
            defaultSopsFile = "${secretsPath}";
            # TODO: what did this do
            # defaultSymlinkPath = "/run/user/1000/secrets";
            # defaultSecretsMountPoint = "/run/user/1000/secrets.d";
        };


    # Syncthing
        sops.secrets.syncthing-durandal = {
            sopsFile    =  "${secretsPath}"; 
        };
            sops.secrets.syncthing-galatea  = {
            sopsFile    =  "${secretsPath}"; 
        };
            sops.secrets.syncthing-lysithea = {
            sopsFile    =  "${secretsPath}"; 
        };
            sops.secrets.syncthing-sif      = {
            sopsFile    =  "${secretsPath}"; 
        };
            sops.secrets.syncthing-iona     = {
            sopsFile    =  "${secretsPath}"; 
        };
    };
}


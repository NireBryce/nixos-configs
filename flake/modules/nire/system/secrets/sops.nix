{ lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { config, pkgs, ... }:
        let   
          isEd25519 = k: k.type == "ed25519";
          getKeyPath = k: k.path;
          keys = builtins.filter isEd25519 config.services.openssh.hostKeys;
          secretsPath = ./secrets.yaml;
        in {
            imports = [
                inputs.sops-nix.nixosModules.sops
            ];

            environment.systemPackages = with pkgs; [
                sops
            ];

        sops = {
            age.sshKeyPaths = map getKeyPath keys;
            defaultSopsFile = "${secretsPath}";
        };

        # Syncthing
        sops.secrets.syncthing-durandal = {
            sopsFile = "${secretsPath}";
        };
        sops.secrets.syncthing-galatea = {
            sopsFile = "${secretsPath}";
        };
        sops.secrets.syncthing-lysithea = {
            sopsFile = "${secretsPath}";
        };
        sops.secrets.syncthing-sif = {
            sopsFile = "${secretsPath}";
        };
        sops.secrets.syncthing-iona = {
            sopsFile = "${secretsPath}";
        };
        };
}

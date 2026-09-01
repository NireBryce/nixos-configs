{ lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { config, pkgs, ... }:
        let   
          isEd25519 = k: k.type == "ed25519";
          getKeyPath = k: k.path;
          keys = builtins.filter isEd25519 config.services.openssh.hostKeys;
          # `"${secretsPath}"` below hands sops-nix a string with context, not
          # a plain path: sops-nix's own manifest-for.nix validates every
          # sops.secrets.*.sopsFile with `builtins.pathExists`, which forces
          # that context to be realised (the file copied into the store as
          # its own path) before it can even check the file is there. In some
          # eval environments -- seen from a sandboxed agent session, 2026-09,
          # on a fully clean tree, so not caused by an uncommitted change --
          # that realisation silently fails and throws `path '<hash>-
          # secrets.yaml' is not valid`, even though the file is present,
          # tracked, and unmodified. Not a bug in this repo or in
          # secrets.yaml itself; see wiki/impermanence-and-secrets.md's
          # Secrets section for the full writeup. Affects any
          # `nix flake check`/`just preflight` run in such a session against
          # a host that imports this module -- doesn't affect a real
          # `just build`/`switch` on the host itself.
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
            # TODO: what did this do
            # defaultSymlinkPath = "/run/user/1000/secrets";
            # defaultSecretsMountPoint = "/run/user/1000/secrets.d";
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

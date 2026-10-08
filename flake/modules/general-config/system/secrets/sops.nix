{ lib, inputs, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    flake.modules.nixos.${moduleName} = { config, pkgs, ... }:
    let   
      isEd25519 = k: k.type == "ed25519";
      getKeyPath = k: k.path;
      keys = builtins.filter isEd25519 config.services.openssh.hostKeys;
      # A plain path value, deliberately NOT interpolated -- the string
      # form (`"${secretsPath}"`) hands sops-nix a string with context.
      # sops-nix's manifest-for.nix validates every sopsFile with
      # `builtins.pathExists`, and on a string-with-context that forces
      # the file to be realised into the store as its own path -- which
      # `nix flake check`'s read-only lazy-trees evaluation cannot do, so
      # any preflight run before something else realised the current
      # secrets.yaml (e.g. right after a re-encrypt changes its store
      # path) died with `path '<hash>-secrets.yaml' is not valid`. The
      # path value needs no store copy until a derivation consumes it,
      # and passes sops-nix's own `builtins.isPath` branch of the same
      # validation. Seen 2026-09-01, root-caused and fixed 2026-09-26
      # with a fresh-file before/after repro; full writeup in
      # wiki/impermanence-and-secrets.md's Secrets section.
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
        defaultSopsFile = secretsPath;
        # TODO: what did this do
        # defaultSymlinkPath = "/run/user/1000/secrets";
        # defaultSecretsMountPoint = "/run/user/1000/secrets.d";
    };

    # No `sops.secrets.*` here on purpose -- this module only sets
    # `defaultSopsFile` and the age keys. A secret declared HERE decrypts on
    # every host importing `system`, i.e. all three Linux hosts; the
    # cube-only ones are declared in the modules that actually use them
    # (`forgejo.nix`, `restic.nix`), each of which says so. See history
    # below for the five that used to sit here.
    };
}

# history
#
# Held five `sops.secrets.syncthing-*` declarations (durandal, galatea,
# lysithea, sif, iona) until 2026-09-08, each setting only `sopsFile` to the
# same `secretsPath` that `defaultSopsFile` already points at. Removed because
# nothing consumed them: no `services.syncthing` anywhere in the tree, and
# galatea/sif/iona are not hosts in `host-config/hosts.nix`. Declaring them meant
# decrypting five unused secrets on every `system` host at activation. The
# removal was written on the `exp-module-cleanup` branch 2026-08-28 and never
# landed there; that branch was deleted once this landed.
#
# `secrets.yaml` still HOLDS those keys, plus a `syncthing-tenacity` this file
# never declared -- deliberately untouched, since an unreferenced key in an
# encrypted file costs nothing and rewriting the file is a real re-encryption.
# If syncthing ever comes back, the material is already there.
#
# Carried a `sops.package` callPackage override 2026-09-22 to 2026-09-24:
# sops-nix 13616fff pinned the buildGo125Module builder in
# sops-install-secrets, and nixpkgs removed that builder with Go 1.25's EOL,
# so the option's own default failed toplevel eval on every `system` host.
# The override called the package directly with the current builder.
# Removed once the sops-nix input moved past the pin (2bd00bd9, plain
# buildGoModule) -- issue #373.

{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # Darwin counterpart to sops.nix (that module is nixos-only -- see
        # its own header -- because nothing on darwin currently consumes
        # `sops.secrets.*` at activation; lysithea has no service depending
        # on an auto-decrypted secret, so there's nothing here to wire
        # `sops.age.sshKeyPaths` for).
        #
        # What darwin DOES need: interactive `sops secrets.yaml` to find an
        # identity at all. sops's default identity-file lookup is platform-
        # dependent -- on Linux it's $XDG_CONFIG_HOME/sops/age/keys.txt
        # (~/.config/sops/age/keys.txt), but on darwin the underlying Go
        # os.UserConfigDir() resolves to ~/Library/Application Support
        # instead. A key sitting at the Linux-XDG path is invisible to a
        # plain `sops` invocation on macOS even when .sops.yaml/secrets.yaml
        # are otherwise correct -- confirmed 2026-08-29 on nire-lysithea:
        # `sops -d secrets.yaml` found no identity and failed against every
        # recipient, but `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops
        # -d secrets.yaml` decrypted cleanly with that same on-disk key file
        # untouched. (That session's actual root cause was two-layered: the
        # `&nire-lysithea` entry in .sops.yaml had also gone stale --
        # enrolled for an SSH host key this machine no longer has, fixed
        # separately by re-running host-age-key.sh and updatekeys -- this
        # module only fixes the platform-path half.)
        #
        # So: point SOPS_AGE_KEY_FILE at the Linux-XDG path directly rather
        # than relying on darwin's own default, or moving/symlinking the key
        # file to satisfy it. Nix-interpolated at eval time (not left for the
        # shell to expand $HOME at sourcing time) -- same reasoning
        # `config.users.users.elly.home` gets used for elsewhere, e.g.
        # security/yubikey.nix.
        flake.modules.darwin.${moduleName} = { config, ... }: {
            environment.variables.SOPS_AGE_KEY_FILE =
                "${config.users.users.elly.home}/.config/sops/age/keys.txt";
        };
}

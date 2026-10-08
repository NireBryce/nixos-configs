# The naming rule, as code: host `nire-<x>` (networking.hostName, and
# `nire-<x>.local` on the LAN via avahi.nix) is the Tailscale device
# `ts-<x>` (MagicDNS; FQDN `ts-<x>.moose-micro.ts.net`). tailscale.nix's
# trap #1 is why this matters; this file makes it something `ssh` and Tab
# know about, on every host including lysithea.
#
# Derived from hosts.nix, not listed: every `nire-*` name in
# nixosConfigurations/darwinConfigurations gets a `ts-*` entry, so a new
# host appears here with no edit. `forge-runner` has no `nire-` prefix and
# is not a tailnet device, so it's skipped by the same rule. The tailnet's
# own names are set in the Tailscale admin console, outside this repo --
# this encodes the convention, it cannot enforce it.
#
# Two outputs, because carapace (which serves `ssh` completion here) takes
# names and descriptions from different places:
#   - ~/.ssh/config `Host ts-<x>` blocks. carapace's ssh host list reads
#     ONLY this file (and known_hosts) -- not /etc/ssh/ssh_config, so a
#     NixOS-level programs.ssh.extraConfig would never reach completion.
#     Also covers `user@ts-<x>`, scp, and zsh.
#   - A carapace overlay for `ssh` carrying a description per name, which
#     carapace-desc.bash surfaces in the blesh menu. Overlays add to the
#     built-in completer rather than replacing it (checked 2026-09-26 with
#     a scratch XDG_CONFIG_HOME), but only for the bare host position --
#     after `user@` the names come from the ~/.ssh/config half alone.
#
# Taking over ~/.ssh/config: Home Manager moves any hand-written file to
# ~/.ssh/config.hm-bak on first activation (backupFileExtension). Entries
# worth keeping go in `settings` below, not back in the file.
#
# ~/.ssh/config is a real file, not HM's usual store symlink: programs.ssh
# renders it, the home.file entry is disabled, and activation installs the
# rendered text as a user-owned 0600 file. ssh refuses a config not owned
# by the user or root, and inside vscode-fhs's bwrap user namespace only
# uid 1000 is mapped -- root-owned store files show as `nobody`, so every
# ssh/git-over-ssh from VS Code's terminal, git integration, and agent
# sessions died with "Bad owner or permissions on ~/.ssh/config" (hit
# 2026-09-28). Hand edits to the file last only until the next switch.
{ config, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

    # Outer `config` on purpose: the flake-parts config is what holds
    # the host roster. Only the attribute names are read, which never
    # forces a host's evaluation.
    fleet = builtins.filter (lib.hasPrefix "nire-")
        (builtins.attrNames config.flake.nixosConfigurations
         ++ builtins.attrNames config.flake.darwinConfigurations);

    tailnetName = host: "ts-${lib.removePrefix "nire-" host}";

    sshOverlay = {
        name       = "ssh";
        completion.positional = [
            (map (host: "${tailnetName host}\t${host} over the tailnet") fleet)
        ];
    };
in {
    # Inner `config`/`lib` are Home Manager's (`fleet` above already read
    # the outer config; only HM's lib has `lib.hm.dag`).
    flake.modules.homeManager.${moduleName} = { config, lib, pkgs, ... }: {
        # # description = "ts-<x> tailnet names for every nire-<x> host, in ~/.ssh/config and ssh completion";
        programs.ssh = {
            enable              = true;
            # No `Host *` defaults block: nothing here wants one, and HM
            # warns until this is set either way.
            enableDefaultConfig = false;
            # Freeform: keys render verbatim, so a misspelled keyword
            # evals clean and ssh ignores it -- read the rendered file
            # back after changing this. (Not `matchBlocks`: deprecated
            # in this HM, with an evaluation warning.)
            settings            = lib.genAttrs (map tailnetName fleet)
                (name: { HostName = name; });
        };

        # Real file, not a symlink -- see the header.
        home.file.".ssh/config".enable = false;
        home.activation.sshConfigRealFile =
            lib.hm.dag.entryAfter [ "linkGeneration" ] ''
                run ${pkgs.coreutils}/bin/install -m 0600 \
                    ${config.home.file.".ssh/config".source} "$HOME/.ssh/config"
            '';

        # JSON is valid YAML, and toJSON gets the "\t" escape right.
        xdg.configFile."carapace/overlays/ssh.yaml".text = builtins.toJSON sshOverlay;
    };
}

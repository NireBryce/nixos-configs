{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # Was cod-completions.nix until 2026-08-22, when this file (carapace)
        # was split out alongside it. carapace is just a binary invoked
        # synchronously per completion request -- no daemon, no system-wide
        # state -- unlike cod, which is a completion *daemon* learning at
        # runtime by watching for `--help` invocations and needs the system
        # install cod-completions.nix reasons about. So carapace lives in
        # home.packages instead, like the rest of nire/shell-config's
        # tooling, and (unlike cod, whose nixpkgs derivation sets
        # meta.broken on darwin -- see the history note in
        # drop-unsupported-packages.nix) it builds cleanly on
        # aarch64-darwin (`just available carapace`, 2026-08-22), so it
        # needs no platform guard and reaches nire-lysithea too.
        #
        # history: cod was removed outright for a few hours the same day,
        # on the reasoning that bash's `complete -F` is last-registration-
        # wins per command and cod's PROMPT_COMMAND hook re-registers a
        # command's completion function every time it sees that command's
        # `--help` run, clobbering whatever carapace had set up for the
        # same name (confirmed overlap at the time: eza, git, nix, podman,
        # systemctl, journalctl, cut). It came back the same day, kept
        # alongside carapace with an ignore-list in cod's own config
        # generated from carapace's spec list -- see cod-completions.nix
        # for the current mechanism and why it turned out not to need
        # hand-maintaining after all.
        #
        # See blesh.nix for why carapace's own bash completer alone doesn't
        # populate descriptions in the blesh menu, and the ble.sh advice hook
        # there that does.
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            home.packages = with pkgs; [
                carapace
            ];
        };
}

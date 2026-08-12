# Shell registration at the system level. zsh itself is configured through
# Home Manager (nire/shell-config/zsh/), same as the Linux hosts; this is only
# the macOS-specific plumbing around that: which shells exist in
# /etc/shells, and stopping the system's own zsh completion setup from
# fighting with Home Manager's.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.darwin.${moduleName} = { pkgs, lib, ... }: {
            # # description = "shell registration and completion plumbing, macOS side";
            environment.shells = with pkgs; [
                bash
                zsh
                fish
            ];

            # System completions need to stay reachable even though the shells
            # themselves are Home-Manager-managed.
            environment.pathsToLink = [
                "/share/zsh"
                "/share/bash-completion"
                "/share/fish"
            ];

            # zsh is handled through Home Manager. Leaving nix-darwin's own
            # completion init on causes an extra `compaudit` run that fights
            # with HM's -- carried over from macos-old, which left this exact
            # note.
            programs.zsh.enable = true;
            programs.zsh.enableCompletion = lib.mkForce false;
        };
}

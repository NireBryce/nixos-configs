{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
                # # description = "opencode: AI coding agent built for the terminal"
                # The SERVER half of opencode is a NixOS module, not an HM
                # one: nireHost/cube/configuration/opencode-server-cube.nix
                # runs `opencode serve` as a systemd user service on
                # nire-cube, bound tailnet-only. Attach with
                # `opencode attach http://ts-cube:3003` (`-c` resumes the
                # last session after a TUI exit).
                home.packages = with pkgs; [
                    opencode
                ];
        };
}

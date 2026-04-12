{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.nixos = { pkgs, ... }:
        environment.systemPackages = with pkgs; [
            nix-output-monitor          # `nom` nix-output-monitor                  https://github.com/maralorn/nix-output-monitor
        ];
    };
}

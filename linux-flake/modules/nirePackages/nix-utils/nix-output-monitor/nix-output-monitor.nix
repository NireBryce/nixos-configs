{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            environment.systemPackages = with pkgs; [
                nix-output-monitor # `nom` nix-output-monitor                  https://github.com/maralorn/nix-output-monitor
            ];
        };
    };
}

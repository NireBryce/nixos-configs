{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # `nvme smart-log` -- NVMe's own wear stats (percentage used,
            # available spare, media errors), more precise for NVMe drives
            # than the ATA-SMART translation smartctl falls back to.
            home.packages = with pkgs; [
                nvme-cli
            ];
        };
}

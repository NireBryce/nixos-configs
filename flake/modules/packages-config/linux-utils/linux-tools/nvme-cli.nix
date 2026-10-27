# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # `nvme smart-log` -- NVMe's own wear stats (percentage used,
        # available spare, media errors), more precise for NVMe drives
        # than the ATA-SMART translation smartctl falls back to.
        home.packages = with pkgs; [
            nvme-cli
        ];
    };
}

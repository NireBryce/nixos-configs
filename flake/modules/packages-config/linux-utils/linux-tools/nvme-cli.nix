# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
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

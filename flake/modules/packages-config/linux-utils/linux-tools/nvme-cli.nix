# dirs-as-categories: the module is named after this file; its categories are the folders above it
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

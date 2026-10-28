# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # package summary: ethtool -- query and change Ethernet NIC settings
        # ethtool https://www.kernel.org/pub/software/network/ethtool/
        home.packages = with pkgs; [
            ethtool
        ];
    };
}

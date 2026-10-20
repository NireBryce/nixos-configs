# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # ethtool https://www.kernel.org/pub/software/network/ethtool/
        home.packages = with pkgs; [
            ethtool
        ];
    };
}

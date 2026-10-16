# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # ethtool https://www.kernel.org/pub/software/network/ethtool/
        home.packages = with pkgs; [
            ethtool
        ];
    };
}

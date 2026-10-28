# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # package summary: aria2 -- CLI download manager (HTTP, FTP, BitTorrent)
        # aria2 -cli download manager
        home.packages = with pkgs; [
            aria2
        ];
    };
}

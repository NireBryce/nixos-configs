# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # wh - magic-wormhole point to point file transfer
        home.packages = with pkgs; [
            magic-wormhole-rs
        ];
    };
}

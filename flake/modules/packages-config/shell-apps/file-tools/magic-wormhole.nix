# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # wh - magic-wormhole point to point file transfer
        home.packages = with pkgs; [
            magic-wormhole-rs
        ];
    };
}

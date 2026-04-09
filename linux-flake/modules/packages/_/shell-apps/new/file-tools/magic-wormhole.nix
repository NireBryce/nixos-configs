{
    description = "wh - magic-wormhole point to point file transfer";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            magic-wormhole-rs
        ];
    };
}

{
    description = "midnight commander file browser";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            mc
        ];
    };
}

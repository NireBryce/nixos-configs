{
    description = "count lines of code";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            tokei
        ];
    };
}

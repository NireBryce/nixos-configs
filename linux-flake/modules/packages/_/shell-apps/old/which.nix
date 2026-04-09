{
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            which
        ];
    };
}

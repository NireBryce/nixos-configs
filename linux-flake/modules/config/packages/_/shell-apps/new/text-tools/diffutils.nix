{
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            diffutils
        ];
    };
}

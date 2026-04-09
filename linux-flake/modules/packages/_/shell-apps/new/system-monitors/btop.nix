{
    description = "`htop` alternative";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            btop
        ];
    };
}

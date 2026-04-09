{
    description = "`rg` is a much faster and more powerful grep alternative";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            ripgrep
        ];
    };
}

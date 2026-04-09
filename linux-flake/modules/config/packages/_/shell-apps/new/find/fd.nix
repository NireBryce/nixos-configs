{
    description = "`find` alternative";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            fd
        ];
    };
}

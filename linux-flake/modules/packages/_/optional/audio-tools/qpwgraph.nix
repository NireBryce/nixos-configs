{
    description = "qpw graph virtual mixer";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            qpwgraph
        ];
    };
}

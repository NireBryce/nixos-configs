# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # virtual mixer
        home.packages = with pkgs; [
            qpwgraph
        ];
    };
}

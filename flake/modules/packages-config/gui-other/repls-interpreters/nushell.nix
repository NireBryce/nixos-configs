# Module file: named after this file; why it looks this way: wiki/module-files.md
{ 
    homeManager = { pkgs, ... }: {
        # nushell - the next generation shell
        # hint: nushell -c for tabular display in any shell
        home.packages = with pkgs; [
            nushell
        ];
    };
}

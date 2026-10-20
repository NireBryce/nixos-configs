# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ 
    homeManager = { pkgs, ... }: {
        # nushell - the next generation shell
        # hint: nushell -c for tabular display in any shell
        home.packages = with pkgs; [
            nushell
        ];
    };
}

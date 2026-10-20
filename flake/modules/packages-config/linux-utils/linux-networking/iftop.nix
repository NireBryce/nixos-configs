# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ 
    homeManager = { pkgs, ... }: {
        # network monitor https://pdw.ex-parrot.com/iftop/
        home.packages = with pkgs; [
            iftop
        ];
    };
}

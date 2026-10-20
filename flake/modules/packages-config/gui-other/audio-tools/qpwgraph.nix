# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # virtual mixer
        home.packages = with pkgs; [
            qpwgraph
        ];
    };
}

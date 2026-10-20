# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # aria2 -cli download manager
        home.packages = with pkgs; [
            aria2
        ];
    };
}

# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # vivid - LS_COLORS generator
        home.packages = with pkgs; [
            vivid
        ];
    };
}

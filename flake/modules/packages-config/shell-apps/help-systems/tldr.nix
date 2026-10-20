# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # tldr - community provided man pages
        home.packages = with pkgs; [
            tldr
        ];
    };
}

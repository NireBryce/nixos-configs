# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # tldr - community provided man pages
        home.packages = with pkgs; [
            tldr
        ];
    };
}

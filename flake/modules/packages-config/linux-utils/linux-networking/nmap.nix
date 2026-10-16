# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # network scanner http://www.nmap.org/
        home.packages = with pkgs; [
            nmap
        ];
    };
}

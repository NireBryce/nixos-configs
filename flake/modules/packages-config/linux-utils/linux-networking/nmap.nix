# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # network scanner http://www.nmap.org/
        home.packages = with pkgs; [
            nmap
        ];
    };
}

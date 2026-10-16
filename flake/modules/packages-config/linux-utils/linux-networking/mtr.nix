# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # description =  "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";
        home.packages = with pkgs; [
            mtr
        ];
    };
}

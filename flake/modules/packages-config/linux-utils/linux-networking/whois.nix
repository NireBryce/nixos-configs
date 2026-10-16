# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # whois lookup https://packages.qa.debian.org/w/whois.html
        home.packages = with pkgs; [
            whois
        ];
    };
}

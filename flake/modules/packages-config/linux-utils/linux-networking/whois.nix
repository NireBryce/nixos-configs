# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # whois lookup https://packages.qa.debian.org/w/whois.html
        home.packages = with pkgs; [
            whois
        ];
    };
}

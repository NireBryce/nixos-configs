{
    description = "whois lookup https://packages.qa.debian.org/w/whois.html";

    homeManager =  { pkgs, ... }: {
        home.packages = with pkgs; [
            whois
        ];
    };
}

{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
        dnsutils                      # `dig` + `nslookup`                        https://www.isc.org/bind/
        ldns                          # provides `drill` a `dig` replacement      https://www.nlnetlabs.nl/projects/ldns/about/
        whois                         # whois lookup                              https://packages.qa.debian.org/w/whois.html
    ];
}


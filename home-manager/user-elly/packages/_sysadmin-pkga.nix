{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
      # fetch
        curl                          # `curl`                                    https://curl.se/download.html
        wget                          # its like curl but different               https://www.gnu.org/software/wget/
      # networking                  # networking                                  # networking
        iftop                         # network monitor                           https://pdw.ex-parrot.com/iftop/
        ipcalc                        # IP address calculator                     https://gitlab.com/ipcalc/ipcalc
        iperf3                        # network tools                             https://software.es.net/iperf/
        mtr                           # traceroute + ping                         https://www.bitwizard.nl/mtr/
        nmap                          # network scanner                           http://www.nmap.org/
        socat                         # openbsd-netcat replacement
    # web/dns                http://www.dest-unreach.org/socat/
        dnsutils                      # `dig` + `nslookup`                        https://www.isc.org/bind/
        ldns                          # provides `drill` a `dig` replacement      https://www.nlnetlabs.nl/projects/ldns/about/
        whois                         # whois lookup                              https://packages.qa.debian.org/w/whois.html
    # linux debugging           # linux debugging                           # linux debugging
        lsof                          # list open files                           https://linux.die.net/man/1/lsof
    ];
}

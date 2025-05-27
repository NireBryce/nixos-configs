{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
      # networking                  # networking                                  # networking
        curl                          # `curl`                                    https://curl.se/download.html
        dnsutils                      # `dig` + `nslookup`                        https://www.isc.org/bind/
        iftop                         # network monitor                           https://pdw.ex-parrot.com/iftop/
        ipcalc                        # IP address calculator                     https://gitlab.com/ipcalc/ipcalc
        iperf3                        # network tools                             https://software.es.net/iperf/
        ldns                          # provides `drill` a `dig` replacement      https://www.nlnetlabs.nl/projects/ldns/about/
        mtr                           # traceroute + ping                         https://www.bitwizard.nl/mtr/
        nmap                          # network scanner                           http://www.nmap.org/
        socat                         # openbsd-netcat replacement                http://www.dest-unreach.org/socat/
        wget                          # its like curl but different               https://www.gnu.org/software/wget/
        whois                         # whois lookup                              https://packages.qa.debian.org/w/whois.html
    # linux debugging           # linux debugging                           # linux debugging
        lsof                          # list open files                           https://linux.die.net/man/1/lsof
    ];
}

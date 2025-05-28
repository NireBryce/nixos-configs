{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
        iftop                         # network monitor                           https://pdw.ex-parrot.com/iftop/
        ipcalc                        # IP address calculator                     https://gitlab.com/ipcalc/ipcalc
        iperf3                        # network tools                             https://software.es.net/iperf/
        mtr                           # traceroute + ping                         https://www.bitwizard.nl/mtr/
        nmap                          # network scanner                           http://www.nmap.org/
        socat                         # openbsd-netcat replacement                http://www.dest-unreach.org/socat/
    ];
}


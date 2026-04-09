{
    description = "network tools https://software.es.net/iperf/";
    
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            iperf3
        ];
    };
}

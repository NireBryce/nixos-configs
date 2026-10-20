# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # network tools https://software.es.net/iperf/
        home.packages = with pkgs; [
            iperf3
        ];
    };
}

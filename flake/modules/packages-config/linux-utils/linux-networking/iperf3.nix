# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # network tools https://software.es.net/iperf/
        home.packages = with pkgs; [
            iperf3
        ];
    };
}

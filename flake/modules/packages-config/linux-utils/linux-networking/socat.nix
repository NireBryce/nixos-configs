# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # openbsd netcat replacement https://www.dest-unreach.org/socat/
        home.packages = with pkgs; [
            socat
        ];
    };
}

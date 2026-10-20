# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # openbsd netcat replacement https://www.dest-unreach.org/socat/
        home.packages = with pkgs; [
            socat
        ];
    };
}

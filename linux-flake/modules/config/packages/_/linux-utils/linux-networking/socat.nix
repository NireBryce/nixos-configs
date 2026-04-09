{
    description = "openbsd netcat replacement https://www.dest-unreach.org/socat/";
    
    homeManager = { pkgs, ... }: {
        home.packages  = with pkgs; [
            socat
        ];
    };
}

{ 
    description = "network scanner http://www.nmap.org/";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            nmap
        ];
    };
}

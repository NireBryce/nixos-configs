{
    description = "provides `dig` + `nslookup`";
    
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            dnsutils
        ];
    };
}

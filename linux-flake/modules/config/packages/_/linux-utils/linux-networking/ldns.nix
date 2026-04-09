{
    description = "provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/";
    
    homeManager =  { pkgs, ... }: {
        home.packages = with pkgs; [
            ldns
        ];
    };
}

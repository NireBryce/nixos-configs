# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # provides `dig` + `nslookup`
        home.packages = with pkgs; [
            dnsutils
        ];
    };
}

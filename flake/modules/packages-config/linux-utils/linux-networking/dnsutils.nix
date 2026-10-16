# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # provides `dig` + `nslookup`
        home.packages = with pkgs; [
            dnsutils
        ];
    };
}

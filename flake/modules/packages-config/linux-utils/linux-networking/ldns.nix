# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/
        home.packages = with pkgs; [
            ldns
        ];
    };
}

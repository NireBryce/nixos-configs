# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/
        home.packages = with pkgs; [
            ldns
        ];
    };
}

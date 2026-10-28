# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # package summary: whois -- domain and IP registration lookup client
        # whois lookup https://packages.qa.debian.org/w/whois.html
        home.packages = with pkgs; [
            whois
        ];
    };
}

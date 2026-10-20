# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # description =  "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";
        home.packages = with pkgs; [
            mtr
        ];
    };
}

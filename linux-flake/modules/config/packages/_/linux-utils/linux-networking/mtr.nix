{
    description =  "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            mtr
        ];
    };
}

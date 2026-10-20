# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # jc converts output into JSON or YAML https://github.com/kellyjonbrazil/jc
        home.packages = with pkgs; [
            jc
        ];
    };
}

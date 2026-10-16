# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # jc converts output into JSON or YAML https://github.com/kellyjonbrazil/jc
        home.packages = with pkgs; [
            jc
        ];
    };
}

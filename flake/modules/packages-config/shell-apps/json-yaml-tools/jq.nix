# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # jq https://github.com/stedolan/jq
        home.packages = with pkgs; [
            jq
        ];
    };
}

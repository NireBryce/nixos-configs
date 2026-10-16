# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: { 
        # yaml jq https://github.com/mikefarah/yq
        home.packages = with pkgs; [
            yq-go
        ];
    };
}

# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: { 
        # yaml jq https://github.com/mikefarah/yq
        home.packages = with pkgs; [
            yq-go
        ];
    };
}

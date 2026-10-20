# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # jq https://github.com/stedolan/jq
        home.packages = with pkgs; [
            jq
        ];
    };
}

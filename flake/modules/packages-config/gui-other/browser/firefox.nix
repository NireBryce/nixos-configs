# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # note: this is also installed as a system package, does that matter?
        home.packages = with pkgs; [ 
            firefox 
        ];
    };
}

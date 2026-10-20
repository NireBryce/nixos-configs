# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: { 
        # description = "better pager for some things https://github.com/walles/moor";
        home.packages = with pkgs; [
            moor # moar renamed to moor https://github.com/walles/moor/pull/305
        ];
    };
}

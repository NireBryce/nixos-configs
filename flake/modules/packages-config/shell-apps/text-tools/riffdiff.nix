# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: { 
        # per-character in-line diff
        home.packages = with pkgs; [
            riffdiff
        ];
    };
}

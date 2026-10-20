# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
            # # description = "herdr: agent multiplexer that lives in your terminal"
            home.packages = with pkgs; [
                herdr
            ];
    };
}

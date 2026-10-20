# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ 
    homeManager = { pkgs, ... }: {
        # description ="kanata - input-level keybinding, platform independent";
        home.packages = with pkgs; [
            kanata
        ];
    };
}

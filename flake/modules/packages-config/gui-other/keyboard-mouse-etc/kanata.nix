# Module file: named after this file; why it looks this way: wiki/module-files.md
{ 
    homeManager = { pkgs, ... }: {
        # description ="kanata - input-level keybinding, platform independent";
        home.packages = with pkgs; [
            kanata
        ];
    };
}

# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

{ 
    homeManager = {
        # micro, what if nano was msword for dos
        programs.micro = {
            enable = true;
            settings = {
                autoclose = false;
                backup = false;
                autosu = true;
                cursorline = true;
                colorscheme = "dukeubuntu-tc";
                difgutter = true;
                eofnewline = true;
                fastdirty = true;
                ignorecase = false;
                keyenu = true;
                mkparents = true;
                savehistory = false;
                tabsize = 2;
                tsbstospaces = true;
                colorcolumn = 81;
                indentchar = "·";
                multiopen = "hsplit";
                parsecursor = true;
                linter = true;
                comment = true;
                tabstospaces = true;
            };
        };
    };
}

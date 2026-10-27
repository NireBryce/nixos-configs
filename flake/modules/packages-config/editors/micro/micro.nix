# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
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

{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.micro ];

    flake.modules.homeManager.micro =
# micro, what if nano was msword for dos
{ ... }:
{
    programs.micro = {
        enable = true;
        settings = {
            autoclose = false;
            backup = false;
            autosu = true;
            cursorline  = true;
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
}
;}

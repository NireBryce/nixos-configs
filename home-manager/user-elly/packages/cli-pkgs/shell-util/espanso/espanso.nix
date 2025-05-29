{

    ...
}:
 
{
    programs.espanso = {
        enable  = true;
        waylandSupport = true;
        configs = [ "./.config/espanso/config/config.yml" ];
    };
    home.file = {# empty for now
        "./.config/espanso/config/config.yml" = {
            source = ./config.yml;
        };
    };
}

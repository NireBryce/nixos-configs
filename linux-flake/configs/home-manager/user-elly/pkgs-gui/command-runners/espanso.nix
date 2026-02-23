# espanso is a text expansion tool that turns a trigger phrase into text
{ den.aspects.pkgs-gui.homeManager = 
{ ... }:
{
    services.espanso = {
        enable  = true;
        waylandSupport = true;
    };
}
;}

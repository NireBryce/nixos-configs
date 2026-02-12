# espanso is a text expansion tool that turns a trigger phrase into text
{ den.aspects.hm.provides.pkgs-gui = 
{ ... }:
{
    services.espanso = {
        enable  = true;
        waylandSupport = true;
    };
}
;}

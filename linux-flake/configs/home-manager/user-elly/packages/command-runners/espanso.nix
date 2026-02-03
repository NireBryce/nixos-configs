# espanso is a text expansion tool that turns a trigger phrase into text
{ flake.modules.homeManager.packages.commandRunners.espanso = 
{ ... }:
{
    services.espanso = {
        enable  = true;
        waylandSupport = true;
    };
}
;}

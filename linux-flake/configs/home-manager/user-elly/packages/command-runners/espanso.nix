# espanso is a text expansion tool that turns a trigger phrase into text
{ den.bundles.hm.command-runners =
{ ... }:
{
    services.espanso = {
        enable  = true;
        waylandSupport = true;
    };
}
;}

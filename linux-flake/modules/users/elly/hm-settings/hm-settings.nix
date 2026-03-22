{ self, inputs, ...}:
{ flake.homeModules.elly-hm-settings = 
{
    home.stateVersion   = "22.11";
    home.username       = "elly";
    home.homeDirectory  = "/home/elly";
}
;}

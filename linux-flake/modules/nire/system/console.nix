{ self, inputs, ...}:
{ flake.modules.nixos.system = 
{ ... }: 
{
    console = {
        keyMap  = "us";
        font    = "Lat2-Terminus16";
    };
}
;}

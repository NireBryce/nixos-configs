{ self, inputs, ...}:
{ flake.nixosModules.system = 
{ ... }: 
{
    console = {
        keyMap  = "us";
        font    = "Lat2-Terminus16";
    };
}
;}

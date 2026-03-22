{ self, inputs, ...}:
{ flake.nixosModules.logitech-g600 = 
{ ... }: 
{
    services.ratbagd.enable = true;         # for piper logitech mouse ctl
}
;}

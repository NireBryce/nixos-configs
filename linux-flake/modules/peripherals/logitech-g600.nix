{ self, inputs, ...}:
{ flake.modules.nixos.logitech-g600 = 
{ ... }: 
{
    services.ratbagd.enable = true;         # for piper logitech mouse ctl
}
;}

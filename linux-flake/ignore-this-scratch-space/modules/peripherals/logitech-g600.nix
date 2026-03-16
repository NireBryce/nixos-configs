{ peripherals.logitech-g600.nixos = 
{ ... }: 
{
    services.ratbagd.enable = true;         # for piper logitech mouse ctl
}
;}

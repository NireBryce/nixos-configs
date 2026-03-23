{ self, inputs, ...}:
{ flake.modules.nixos.zsa-moonlander = 
{ ... }: 
{
    hardware.keyboard.zsa.enable        = true;         # zsa keyboard package
}
;}

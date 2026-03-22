{ self, inputs, ...}:
{ flake.nixosModules.zsa-moonlander = 
{ ... }: 
{
    hardware.keyboard.zsa.enable        = true;         # zsa keyboard package
}
;}

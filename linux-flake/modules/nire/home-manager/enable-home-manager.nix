{ self, inputs, ...}:
{ flake.nixosModules.home-manager =
{
    imports = [
        inputs.home-manager.flakeModules.home-manager
    ];
}
;}

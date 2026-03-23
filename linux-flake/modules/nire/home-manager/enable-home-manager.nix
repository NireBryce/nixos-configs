{ self, inputs, ...}:
{ flake.modules.nixos.home-manager =
{
    imports = [
        inputs.home-manager.flakeModules.home-manager
    ];
}
;}

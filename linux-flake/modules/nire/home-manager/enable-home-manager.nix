{ config, inputs, ... }:
{
    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.home-manager ];

    flake.modules.nixos.home-manager =
{
    imports = [
        inputs.home-manager.nixosModules.home-manager
    ];
}
;}

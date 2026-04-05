# todo: figure out how to do this in den
{ self, inputs, ... }:
{
    flake.nixosConfigurations.nire-durandal = inputs.nixpkgs.lib.nixosSystem {
        modules = [
            self.modules.nixos.durandalConfiguration
        ];
    };

}

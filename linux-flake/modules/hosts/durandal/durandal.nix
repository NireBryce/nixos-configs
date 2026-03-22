{ self, inputs, ... }:
{
    flake.nixosConfigurations.nire-durandal = inputs.nixpkgs.lib.nixosSystem {
        modules = [ ];
    };
}

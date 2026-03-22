{ self, inputs, ... }:
{
    flake.nixosConfigurations.nire-durandal = inputs.nixpkgs.lib.nixosStystem {
        modules = [ ];
    };
}

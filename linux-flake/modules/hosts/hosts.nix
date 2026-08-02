{ self, inputs, ... }:
{
    flake.nixosConfigurations.nire-durandal = inputs.nixpkgs.lib.nixosSystem {
        modules = [
            self.modules.nixos.durandalConfiguration
        ];
    };

    flake.nixosConfigurations.nire-tenacity = inputs.nixpkgs.lib.nixosSystem {
        modules = [
            self.modules.nixos.tenacityConfiguration
        ];
    };
}

{ self, inputs, ... }:
{
    flake.nixosConfigurations.nire-durandal = inputs.nixpkgs.lib.nixosSystem {
        modules = with self.nixosModules; [
            durandalConfiguration
        ];
    };
    # flake.nixosConfigurations.nire-tenacity = inputs.nixpkgs.lib.nixosSystem {
    #     modules = with self.nixosModules; [
    #         durandalConfiguration
    #     ];
    # };
}

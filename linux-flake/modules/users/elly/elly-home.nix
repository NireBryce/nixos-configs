{ self, inputs, ...}:
{ 
    flake.homeConfigurations."elly@nire-durandal" = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
        modules = [
            self.modules.homeManager.ellyHomeManager
        ];
    };
 }

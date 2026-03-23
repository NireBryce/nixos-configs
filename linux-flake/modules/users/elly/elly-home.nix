{ self, inputs, ...}:
{ 
    flake.homeConfigurations."elly@nire-durandal" = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
        modules = with self.modules.homeManager; [
            elly
        ];
    };
 }

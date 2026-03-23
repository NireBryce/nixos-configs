{ self, inputs, ...}:
{ 
    flake.homeConfigurations."elly@nire-durandal" = inputs.home-manager.lib.homeManagerConfiguration {
        modules = with self.homeModules; [ 
            elly
        ];
    };
 }

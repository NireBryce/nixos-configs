{ self, inputs, ...}:
{ 
    flake.homeConfigurations.elly = inputs.home-manager.lib.homeManagerConfiguration {
        modules = [ ];
    };
 }

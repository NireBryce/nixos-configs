{ self, inputs, ...}:
{ 
    flake.homeConfigurations."elly@nire-durandal" = inputs.home-manager.lib.homeManagerConfiguration {
        modules = [ ];
    };
 }

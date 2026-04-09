{ 
    nire.nix =
    { inputs, ... }:
    {
        provides = {
            all = { lib, config }: { includes = lib.attrValues (removeAttrs config.provides [ "all" ]); };
            
            nix-settings = { imports = [ (inputs.import-tree ./_/nix-settings) ]; };
            
            nix-utils = { imports = [ (inputs.import-tree ./_/nix-utils) ]; };
        };
    };
}


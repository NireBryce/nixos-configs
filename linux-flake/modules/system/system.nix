{ nire.system =
{ inputs, ... }:
{ 
    provides = {
        all = { lib, config }: { includes = lib.attrValues (removeAttrs config.provides [ "all" ]); };
        
        core = { imports = [ (inputs.import-tree ./_/core) ]; };
        
        gaming = { imports = [ (inputs.import-tree ./_/gaming) ]; };
        
        optional = { imports = [ (inputs.import-tree ./_/optional) ]; };
        
        base-system-packages = { imports = [ (inputs.import-tree ./_/base-system-packages) ]; };
    };
};
}

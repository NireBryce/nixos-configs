{ 
    nire.desktop-env =
    { inputs, ... }:
    {
        provides = {
            all = { lib, config }: { includes = lib.attrValues (removeAttrs config.provides [ "all" ]); };
            
            jovian = { imports = [ (inputs.import-tree ./_/jovian) ]; };
            
            kde = { imports = [ (inputs.import-tree ./_/kde) ]; };
        };
    };
}

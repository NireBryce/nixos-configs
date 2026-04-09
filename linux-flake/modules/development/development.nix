{ 
    nire.development =
    { inputs, ... }:
    {
        provides = {
            all = { lib, config }: { includes = lib.attrValues (removeAttrs config.provides [ "all" ]); };
            
            langs = { imports = [ (inputs.import-tree ./_/langs) ]; };
            
            tools = { imports = [ (inputs.import-tree ./_/tools) ]; };
        };
    };
}

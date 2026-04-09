{ 
    nire.peripherals =
    { inputs, ... }:
    {
        provides = {
            all = { lib, config }: { includes = lib.attrValues (removeAttrs config.provides [ "all" ]); };
            
            logitech-g600 = { imports = [ (inputs.import-tree ./_/logitech-g600) ]; };
            
            zsa-moonlander = { imports = [ (inputs.import-tree ./_/zsa-moonlander) ]; };
        };
    };
}

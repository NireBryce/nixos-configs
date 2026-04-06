{ 
    nire.peripherals =
    { inputs, ... }:
    {
        provides = {
            all = { imports = [ (inputs.import-tree ./_) ]; };
            logitech-g600 = { imports = [ (inputs.import-tree ./_/logitech-g600) ]; };
            zsa-moonlander = { imports = [ (inputs.import-tree ./_/zsa-moonlander) ]; };
        };
    };
}

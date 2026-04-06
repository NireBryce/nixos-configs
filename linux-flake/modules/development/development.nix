{ 
    nire.development =
    { inputs, ... }:
    {
        provides = {
            langs = { imports = [ (inputs.import-tree ./_/langs) ]; };
            tools = { imports = [ (inputs.import-tree ./_/tools) ]; };
        };
    };
}

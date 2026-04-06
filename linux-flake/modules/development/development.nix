{ 
    nire.development =
    { inputs, ... }:
    {
        provides = {
            all = { imports = [ (inputs.import-tree ./_) ]; };
            langs = { imports = [ (inputs.import-tree ./_/langs) ]; };
            tools = { imports = [ (inputs.import-tree ./_/tools) ]; };
        };
    };
}

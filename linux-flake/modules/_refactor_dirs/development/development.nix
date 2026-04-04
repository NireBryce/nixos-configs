{ 
    nire.development =
    { inputs, ... }:
    {
        provides = {
            devenv = { imports = [ (inputs.import-tree ./_/devenv) ]; };
            rust = { imports = [ (inputs.import-tree ./_/rust) ]; };
        };
    };
}

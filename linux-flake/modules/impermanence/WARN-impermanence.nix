# WARN: This will delete root at boot if you invoke it, so know what you're doing

{ 
    nire.impermanence =
    { inputs, ... }:
    {
        provides = {
            impermanence = { imports = [ (inputs.import-tree ./_/impermanence) ]; };
        };
    };
}

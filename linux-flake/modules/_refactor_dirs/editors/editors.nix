{ 
    nire.editors =
    { inputs, ... }:
    {
        provides = {
            vscode = { imports = [ (inputs.import-tree ./_/vscode) ]; };
        };
    };
}

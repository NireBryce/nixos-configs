{ 
    nire.editors =
    { inputs, ... }:
    {
        provides = {
            vscode = { imports = [ (inputs.import-tree ./_/vscode) ]; };
            neovim = { imports = [ (inputs.import-tree ./_/neovim) ]; };
            micro = { imports = [ (inputs.import-tree ./_/micro) ]; };
        };
    };
}

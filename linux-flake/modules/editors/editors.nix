{ 
    nire.editors =
    { inputs, ... }:
    {
        provides = {
            all = { imports = [ (inputs.import-tree ./_) ]; };
            vscode = { imports = [ (inputs.import-tree ./_/vscode) ]; };
            neovim = { imports = [ (inputs.import-tree ./_/neovim) ]; };
            micro = { imports = [ (inputs.import-tree ./_/micro) ]; };
        };
    };
}

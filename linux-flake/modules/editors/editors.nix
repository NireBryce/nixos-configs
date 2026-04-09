{
    nire.editors = { inputs, lib, ... }:
    let
        provides = {
            vscode = { imports = [ (inputs.import-tree ./_/vscode) ]; };
            neovim = { imports = [ (inputs.import-tree ./_/neovim) ]; };
            micro  = { imports = [ (inputs.import-tree ./_/micro) ]; };
        };
    in {
        provides = provides // {
            all = { includes = lib.attrValues provides; };
        };
    };
}

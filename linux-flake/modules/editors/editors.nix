{ 
    nire.editors = { inputs, ... }: {
        provides = {
            all = { lib, config }: { includes = lib.attrValues (removeAttrs config.provides [ "all" ]); };
            
            vscode = { imports = [ (inputs.import-tree ./_/vscode) ]; };
            
            neovim = { imports = [ (inputs.import-tree ./_/neovim) ]; };
            
            micro = { imports = [ (inputs.import-tree ./_/micro) ]; };
        };
    };
}

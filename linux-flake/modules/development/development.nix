{ 
    nire.development =
    { inputs, ... }:
    {
        provides = {
            bash-dev = { imports = [ (inputs.import-tree ./_/bash-dev) ]; };
            ai-tools = { imports = [ (inputs.import-tree ./_/ai-tools) ]; };
            git = { imports = [ (inputs.import-tree ./_/git) ]; };
            devenv = { imports = [ (inputs.import-tree ./_/devenv) ]; };
            python-dev = { imports = [ (inputs.import-tree ./_/python-dev) ]; };
            rust = { imports = [ (inputs.import-tree ./_/rust) ]; };
            typescript = { imports = [ (inputs.import-tree ./_/typescript) ]; };
        };
    };
}

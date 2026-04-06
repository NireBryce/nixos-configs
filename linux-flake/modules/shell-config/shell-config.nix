{
    nire.shell =
    { inputs, ... }:
    {
        provides = {
            all = { imports = [ (inputs.import-tree ./_) ]; };
            bash = { imports = [ (inputs.import-tree ./_/bash) ]; };
            fish = { imports = [ (inputs.import-tree ./_/fish) ]; };
            shell-env = { imports = [ (inputs.import-tree ./_/shell-env) ]; };
            zsh = { imports = [ (inputs.import-tree ./_/zsh) ]; };
        };
    };
}

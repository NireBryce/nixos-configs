{
    nire.shell =
    { inputs, ... }:
    {
        provides = {
            bash = { imports = [ (inputs.import-tree ./_/bash) ]; };
            fish = { imports = [ (inputs.import-tree ./_/fish) ]; };
            shell-env = { imports = [ (inputs.import-tree ./_/shell-env) ]; };
            shell-apps = { imports = [ (inputs.import-tree ./_/shell-apps) ]; };
            zsh = { imports = [ (inputs.import-tree ./_/zsh) ]; };
        };
    };
}

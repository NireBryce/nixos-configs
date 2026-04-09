{
    nire.shell-config =
    { inputs, ... }:
    {
        provides = {
            all = { lib, config }: { includes = lib.attrValues (removeAttrs config.provides [ "all" ]); };
            
            bash = { imports = [ (inputs.import-tree ./_/bash) ]; };
            
            fish = { imports = [ (inputs.import-tree ./_/fish) ]; };
            
            shell-env = { imports = [ (inputs.import-tree ./_/shell-env) ]; };
            
            zsh = { imports = [ (inputs.import-tree ./_/zsh) ]; };
        };
    };
}

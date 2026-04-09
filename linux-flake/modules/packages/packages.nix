{
    nire.packages =
    { inputs, ... }:
    {
        provides = {
            all = { lib, config }: { includes = lib.attrValues (removeAttrs config.provides [ "all" ]); };

            linux-utils = { imports = [ (inputs.import-tree ./_/linux-utils) ]; };
            
            optional = { imports = [ (inputs.import-tree ./_/optional) ]; };
            
            shell-apps = { imports = [ (inputs.import-tree ./_/shell-apps) ]; };
            
            terminals = { imports = [ (inputs.import-tree ./_/terminals) ]; };
        };
    };
}

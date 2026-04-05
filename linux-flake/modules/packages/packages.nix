{
    nire.packages =
    { inputs, ... }:
    {
        provides = {
            linux-utils = { imports = [ (inputs.import-tree ./_/linux-utils) ]; };
            optional = { imports = [ (inputs.import-tree ./_/optional) ]; };
            shell-apps = { imports = [ (inputs.import-tree ./_/shell-apps) ]; };
            terminals = { imports = [ (inputs.import-tree ./_/terminals) ]; };
        };
    };
}

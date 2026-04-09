{ inputs, lib, ... }: {
    nire.packages = 
    let
        provides = {
            mac-apps    = { imports = [ (inputs.import-tree ./_/mac-apps) ]; };
            linux-utils = { imports = [ (inputs.import-tree ./_/linux-utils) ]; };
            optional    = { imports = [ (inputs.import-tree ./_/optional) ]; };
            shell-apps  = { imports = [ (inputs.import-tree ./_/shell-apps) ]; };
            terminals   = { imports = [ (inputs.import-tree ./_/terminals) ]; };
        };
    in {
        provides = provides // {
            all = { includes = lib.attrValues provides; };
        };
    };
}

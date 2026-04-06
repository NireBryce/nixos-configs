{ nire.system =
{ inputs, ... }:
{ 
    provides = {
        all = { imports = [ (inputs.import-tree ./_) ]; };
        core = { imports = [ (inputs.import-tree ./_/core) ]; };
        gaming = { imports = [ (inputs.import-tree ./_/gaming) ]; };
        optional = { imports = [ (inputs.import-tree ./_/optional) ]; };
        base-system-packages = { imports = [ (inputs.import-tree ./_/base-system-packages) ]; };
    };
};
}

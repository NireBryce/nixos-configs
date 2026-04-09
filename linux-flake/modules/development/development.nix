{
    nire.development = { inputs, lib, ... }:
    let
        provides = {
            langs = { imports = [ (inputs.import-tree ./_/langs) ]; };
            tools = { imports = [ (inputs.import-tree ./_/tools) ]; };
        };
    in {
        provides = provides // {
            all = { includes = lib.attrValues provides; };
        };
    };
}

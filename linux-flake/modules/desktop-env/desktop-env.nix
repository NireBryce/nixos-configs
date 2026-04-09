{
    nire.desktop-env = { inputs, lib, ... }:
    let
        provides = {
            jovian = { imports = [ (inputs.import-tree ./_/jovian) ]; };
            kde    = { imports = [ (inputs.import-tree ./_/kde) ]; };
        };
    in {
        provides = provides // {
            all = { includes = lib.attrValues provides; };
        };
    };
}

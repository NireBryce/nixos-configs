{ 
    nire.desktop-env =
    { inputs, ... }:
    {
        provides = {
            jovian = { imports = [ (inputs.import-tree ./_/jovian) ]; };
            kde = { imports = [ (inputs.import-tree ./_/kde) ]; };
        };
    };
}

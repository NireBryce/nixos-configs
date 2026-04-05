{ nire.pkm =
    { inputs, ... }:
    {
        description = "personal knowledge management";
        provides = {
            history = { imports = [ (inputs.import-tree ./_/history) ]; };
            office = { imports = [ (inputs.import-tree ./_/office) ]; };
            notes = { imports = [ (inputs.import-tree ./_/notes) ]; };
        };
    };
}

{
    nire.durandal = {
        description = "nire-durandal, workstation and gaming PC";
        
        provides = 
        { imports, ... }:
        {
            configuration =  { imports = [ (imports.import-tree ./_/configuration) ]; };
            hardware = { imports = [ (imports.import-tree ./_/hardware) ]; };
        };
    };
}

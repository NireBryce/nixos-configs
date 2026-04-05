{
    nire.elly = 
    { inputs, ... }:
    {
        provides = {
            git = { imports = [ (inputs.import-tree ./_/git) ]; };
            session = { imports = [ (inputs.import-tree ./_/session) ]; };
            home-manager-settings = { imports = [ (inputs.import-tree ./_/home-manager-settings) ]; };
            user-settings = { imports = [ (inputs.import-tree ./_/user-settings) ]; };
        };
    };
}

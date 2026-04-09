{ inputs, lib, ... }: {
    nire.nix = 
    let
        provides = {
            nix-settings = { imports = [ (inputs.import-tree ./_/nix-settings) ]; };
            nix-utils    = { imports = [ (inputs.import-tree ./_/nix-utils) ]; };
        };
    in {
        provides = provides // {
            all = { includes = lib.attrValues provides; };
        };
    };
}

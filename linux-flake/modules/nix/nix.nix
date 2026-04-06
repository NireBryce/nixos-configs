{ nire.nix =
{ inputs, ... }:
{
    provides = {
        all = { imports = [ (inputs.import-tree ./_) ]; };
        nix-settings = { imports = [ (inputs.import-tree ./_/nix-settings) ]; };
        nix-utils = { imports = [ (inputs.import-tree ./_/nix-utils) ]; };
    };
};
}


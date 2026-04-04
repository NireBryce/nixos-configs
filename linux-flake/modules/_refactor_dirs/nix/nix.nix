{ nire.nix =
{ inputs, ... }:
{
    provides = {
        nix-settings = { imports = [ (inputs.import-tree ./_/nix-settings) ]; };
        nix-utils = { imports = [ (inputs.import-tree ./_/nix-utils) ]; };
    };
};
}


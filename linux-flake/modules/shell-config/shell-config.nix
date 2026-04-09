{ inputs, lib, ... }: {
    nire.shell-config =
    let
        provides = {
            bash      = { imports = [ (inputs.import-tree ./_/bash) ]; };
            fish      = { imports = [ (inputs.import-tree ./_/fish) ]; };
            shell-env = { imports = [ (inputs.import-tree ./_/shell-env) ]; };
            zsh       = { imports = [ (inputs.import-tree ./_/zsh) ]; };
        };
    in {
        provides = provides // {
            all = { includes = lib.attrValues provides; };
        };
    };
}

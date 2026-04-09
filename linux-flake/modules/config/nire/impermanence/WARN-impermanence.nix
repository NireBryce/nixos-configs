{ inputs, ... }:
{
    nire.impermanence = 
    # WARN: This will delete root at boot if you invoke it, so know what you're doing   
    let
        provides = {
            impermanence = { imports = [ (inputs.import-tree ./_/impermanence) ]; };
        };
    in {
        provides = provides;
    };
}

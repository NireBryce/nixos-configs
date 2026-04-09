{ inputs, ... }: {
    nire.hardware = 
    let
        provides = {
            amdcpu = { imports = [ (inputs.import-tree ./_/amd/amdcpu) ]; };
            amdgpu = { imports = [ (inputs.import-tree ./_/amd/amdgpu) ]; };
            amd    = { imports = [ (inputs.import-tree ./_/amd) ]; };
        };
    in {
        provides = provides;
    };
}

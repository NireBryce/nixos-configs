{ 
    nire.hardware =
    { inputs, ... }:
    {
        provides = {
            amdcpu = { imports = [ (inputs.import-tree ./_/amdgpu) ]; };
            amdgpu = { imports = [ (inputs.import-tree ./_/amdcpu) ]; };
        };
    };
}
